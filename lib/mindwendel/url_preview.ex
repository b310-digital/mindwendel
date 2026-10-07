defmodule Mindwendel.UrlPreview do
  import Bitwise

  def extract_url(string \\ "") do
    match =
      Regex.run(
        ~r/((?:http|https):\/\/[\w-]+\.[\w-]+[\w\.,@?^=%&:\/\~+#-]*[\w@?^=%&\/\~+#-]?)/,
        string
      )

    if match == nil do
      ""
    else
      List.first(match)
    end
  end

  @empty_preview [title: "", description: "", img_preview_url: ""]
  @redirect_statuses [301, 302, 303, 307, 308]
  # Bytes allowed on top of max_body_size for the status line, headers and TLS
  @max_overhead_size 64_000

  # Address ranges that must never be fetched. Based on the IANA special-purpose
  # address registries (RFC 6890):
  # https://www.iana.org/assignments/iana-ipv4-special-registry
  # https://www.iana.org/assignments/iana-ipv6-special-registry
  #
  # Ranges are `{network, prefix_length}`, i.e. the CIDR notation 10.0.0.0/8 is
  # `{{10, 0, 0, 0}, 8}`: an address matches if its first `prefix_length` bits
  # equal those of the network (see in_range?/2).
  @blocked_ipv4_ranges [
    # 0.0.0.0/8 "this network", 0.0.0.0 often reaches localhost (RFC 791 §3.2)
    {{0, 0, 0, 0}, 8},
    # 10.0.0.0/8 private network (RFC 1918)
    {{10, 0, 0, 0}, 8},
    # 100.64.0.0/10 shared address space / carrier-grade NAT (RFC 6598)
    {{100, 64, 0, 0}, 10},
    # 127.0.0.0/8 loopback (RFC 1122 §3.2.1.3)
    {{127, 0, 0, 0}, 8},
    # 169.254.0.0/16 link-local (RFC 3927), includes the cloud metadata
    # endpoint 169.254.169.254 (AWS, GCP, Azure) exposing credentials
    {{169, 254, 0, 0}, 16},
    # 172.16.0.0/12 private network (RFC 1918)
    {{172, 16, 0, 0}, 12},
    # 192.0.0.0/24 IETF protocol assignments (RFC 6890 §2.1)
    {{192, 0, 0, 0}, 24},
    # 192.0.2.0/24 documentation TEST-NET-1 (RFC 5737)
    {{192, 0, 2, 0}, 24},
    # 192.88.99.0/24 6to4 relay anycast (RFC 3068, deprecated by RFC 7526)
    {{192, 88, 99, 0}, 24},
    # 192.168.0.0/16 private network (RFC 1918)
    {{192, 168, 0, 0}, 16},
    # 198.18.0.0/15 network benchmarking (RFC 2544)
    {{198, 18, 0, 0}, 15},
    # 198.51.100.0/24 documentation TEST-NET-2 (RFC 5737)
    {{198, 51, 100, 0}, 24},
    # 203.0.113.0/24 documentation TEST-NET-3 (RFC 5737)
    {{203, 0, 113, 0}, 24},
    # 224.0.0.0/4 multicast (RFC 5771)
    {{224, 0, 0, 0}, 4},
    # 240.0.0.0/4 reserved (RFC 1112 §4), includes the limited broadcast
    # address 255.255.255.255 (RFC 919 §7)
    {{240, 0, 0, 0}, 4}
  ]

  # IPv6 addresses are tuples of eight 16-bit segments, so 0xFE80 is "fe80".
  # Formats that embed an IPv4 address (IPv4-mapped, IPv4-translated, NAT64,
  # 6to4) are not listed here, public_address?/1 checks the embedded IPv4
  # address against @blocked_ipv4_ranges instead.
  @blocked_ipv6_ranges [
    # ::/96 covers the unspecified address :: (RFC 4291 §2.5.2), the loopback
    # ::1 (RFC 4291 §2.5.3) and the deprecated IPv4-compatible addresses
    # ::a.b.c.d (RFC 4291 §2.5.5.1)
    {{0, 0, 0, 0, 0, 0, 0, 0}, 96},
    # 64:ff9b:1::/48 local-use IPv4/IPv6 translation (RFC 8215)
    {{0x64, 0xFF9B, 1, 0, 0, 0, 0, 0}, 48},
    # 100::/64 discard-only (RFC 6666)
    {{0x100, 0, 0, 0, 0, 0, 0, 0}, 64},
    # 2001::/23 IETF protocol assignments (RFC 2928), includes Teredo
    # 2001::/32 (RFC 4380) which tunnels to arbitrary IPv4 addresses
    {{0x2001, 0, 0, 0, 0, 0, 0, 0}, 23},
    # 2001:db8::/32 documentation (RFC 3849)
    {{0x2001, 0xDB8, 0, 0, 0, 0, 0, 0}, 32},
    # fc00::/7 unique local addresses, the IPv6 private networks (RFC 4193)
    {{0xFC00, 0, 0, 0, 0, 0, 0, 0}, 7},
    # fe80::/10 link-local (RFC 4291 §2.5.6)
    {{0xFE80, 0, 0, 0, 0, 0, 0, 0}, 10},
    # fec0::/10 site-local, deprecated (RFC 3879)
    {{0xFEC0, 0, 0, 0, 0, 0, 0, 0}, 10},
    # ff00::/8 multicast (RFC 4291 §2.7)
    {{0xFF00, 0, 0, 0, 0, 0, 0, 0}, 8}
  ]

  def fetch_url(url \\ "", opts \\ []) do
    case fetch_body(url, opts) do
      {:ok, body} -> body |> Floki.parse_document() |> handle_parsing()
      {:error, _reason} -> {:error, @empty_preview}
    end
  end

  @doc """
  Fetches the body of an http(s) url while protecting against SSRF.

  Every hop (including redirect targets) is resolved once (A and AAAA), all
  resolved addresses must be public, and the connection is made to the
  validated address (Host header, SNI and certificate check use the hostname).

  Options:
    * `:timeout` - total time in ms for all hops, including reading the body
    * `:max_redirects` - maximum number of redirects to follow
    * `:max_body_size` - bytes to read at most, the rest of the body is dropped
    * `:allowed_ips` - addresses allowed even though they are not public
    * `:allow_public_ips` - set to false to only allow `:allowed_ips` (used in tests)
    * `:resolver` - function resolving a hostname to `{:ok, [ip]}`
  """
  def fetch_body(url, opts \\ []) do
    config = Application.get_env(:mindwendel, __MODULE__, [])

    opts =
      Keyword.merge(
        [
          timeout: 5_000,
          max_redirects: 3,
          max_body_size: 1_000_000,
          allowed_ips: Keyword.get(config, :allowed_ips, []),
          allow_public_ips: Keyword.get(config, :allow_public_ips, true)
        ],
        opts
      )

    deadline = System.monotonic_time(:millisecond) + opts[:timeout]
    opts = Keyword.put_new(opts, :resolver, &resolve(&1, deadline))

    with {:ok, uri} <- parse_url(url) do
      fetch_uri(uri, opts[:max_redirects], deadline, opts)
    end
  end

  @doc """
  Returns true if the IPv4 or IPv6 address tuple is a public address, false for
  addresses in @blocked_ipv4_ranges or @blocked_ipv6_ranges.
  """
  # IPv6 formats that embed an IPv4 address reach that IPv4 address (e.g.
  # ::ffff:127.0.0.1 connects to 127.0.0.1), so the embedded address is checked.
  # The IPv4 address spans two 16-bit segments (`high` and `low`).

  # ::ffff:0:0/96 IPv4-mapped, ::ffff:a.b.c.d (RFC 4291 §2.5.5.2)
  def public_address?({0, 0, 0, 0, 0, 0xFFFF, high, low}), do: public_address?(ipv4(high, low))
  # ::ffff:0:0:0/96 IPv4-translated, ::ffff:0:a.b.c.d (RFC 2765 §2.1)
  def public_address?({0, 0, 0, 0, 0xFFFF, 0, high, low}), do: public_address?(ipv4(high, low))
  # 64:ff9b::/96 NAT64 well-known prefix, 64:ff9b::a.b.c.d (RFC 6052 §2.1)
  def public_address?({0x64, 0xFF9B, 0, 0, 0, 0, high, low}), do: public_address?(ipv4(high, low))
  # 2002::/16 6to4, the IPv4 address follows the prefix: 2002:AABB:CCDD:: (RFC 3056 §2)
  def public_address?({0x2002, high, low, _, _, _, _, _}), do: public_address?(ipv4(high, low))

  def public_address?(ip) when tuple_size(ip) == 4,
    do: not Enum.any?(@blocked_ipv4_ranges, &in_range?(ip, &1))

  def public_address?(ip) when tuple_size(ip) == 8,
    do: not Enum.any?(@blocked_ipv6_ranges, &in_range?(ip, &1))

  def public_address?(_ip), do: false

  # Splits two 16-bit segments into four bytes: 0x7F00, 0x0001 -> {127, 0, 0, 1}
  defp ipv4(high, low), do: {high >>> 8, high &&& 0xFF, low >>> 8, low &&& 0xFF}

  # Compares the first `prefix_length` bits by dropping all other bits of the
  # address and the network: 32 bits per IPv4 address, 128 bits per IPv6 address.
  defp in_range?(ip, {network, prefix_length}) do
    shift = tuple_size(ip) * segment_bits(ip) - prefix_length
    ip_to_integer(ip) >>> shift == ip_to_integer(network) >>> shift
  end

  defp ip_to_integer(ip) do
    bits = segment_bits(ip)
    ip |> Tuple.to_list() |> Enum.reduce(0, fn segment, acc -> (acc <<< bits) + segment end)
  end

  defp segment_bits(ip) when tuple_size(ip) == 4, do: 8
  defp segment_bits(ip) when tuple_size(ip) == 8, do: 16

  defp parse_url(url) when is_binary(url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme, host: host, port: port} = uri}
      when scheme in ["http", "https"] and is_binary(host) and host != "" and
             port in 1..65_535 ->
        {:ok, uri}

      _ ->
        {:error, :invalid_url}
    end
  end

  defp parse_url(_url), do: {:error, :invalid_url}

  defp fetch_uri(uri, redirects_left, deadline, opts) do
    with {:ok, ips} <- resolve_public(uri.host, deadline, opts),
         {:ok, {status, headers, body}} <- request(uri, ips, deadline, opts) do
      case status do
        200 ->
          {:ok, body}

        status when status in @redirect_statuses ->
          redirect(uri, headers, redirects_left, deadline, opts)

        status ->
          {:error, {:http_status, status}}
      end
    end
  end

  defp redirect(_uri, _headers, 0, _deadline, _opts), do: {:error, :too_many_redirects}

  defp redirect(uri, headers, redirects_left, deadline, opts) do
    case List.keyfind(headers, "location", 0) do
      {_, location} ->
        with {:ok, target} <- parse_url(uri |> URI.merge(location) |> URI.to_string()) do
          fetch_uri(target, redirects_left - 1, deadline, opts)
        end

      nil ->
        {:error, :missing_location}
    end
  end

  defp resolve_public(host, deadline, opts) do
    ips =
      case ip_literal(host) do
        {:ok, ip} -> {:ok, [ip]}
        {:error, _} -> resolve_until(host, deadline, opts[:resolver])
      end

    with {:ok, ips} <- ips do
      if ips != [] and Enum.all?(ips, &allowed_address?(&1, opts)) do
        # Prefer IPv4, as all addresses are valid this does not weaken the check
        {:ok, Enum.sort_by(ips, &tuple_size/1)}
      else
        {:error, :forbidden_address}
      end
    end
  end

  defp allowed_address?(ip, opts),
    do: ip in opts[:allowed_ips] or (opts[:allow_public_ips] and public_address?(ip))

  defp ip_literal(host), do: :inet.parse_strict_address(String.to_charlist(host))

  # The native resolver ignores the timeout of :inet.getaddrs/3, so the
  # deadline is enforced around the whole lookup.
  defp resolve_until(host, deadline, resolver) do
    task = Task.async(fn -> resolver.(host) end)

    case Task.yield(task, remaining_time(deadline)) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      _ -> {:error, :timeout}
    end
  end

  defp resolve(host, deadline) do
    host = String.to_charlist(host)

    ips =
      for family <- [:inet, :inet6],
          {:ok, addresses} <- [:inet.getaddrs(host, family, remaining_time(deadline))],
          address <- addresses,
          uniq: true,
          do: address

    if ips == [], do: {:error, :nxdomain}, else: {:ok, ips}
  end

  defp request(uri, ips, deadline, opts) do
    with {:ok, conn} <- connect(uri, ips, deadline) do
      try do
        headers = [{"host", host_header(uri)}, {"accept", "text/html"}]

        case Mint.HTTP.request(conn, "GET", request_target(uri), headers, nil) do
          {:ok, conn, ref} -> receive_response(conn, ref, {nil, [], [], 0}, deadline, opts)
          {:error, _conn, reason} -> {:error, reason}
        end
      after
        Mint.HTTP.close(conn)
      end
    end
  end

  defp connect(uri, ips, deadline) do
    scheme = if uri.scheme == "https", do: :https, else: :http

    Enum.reduce_while(ips, {:error, :connection_failed}, fn ip, error ->
      case connect_to_ip(scheme, ip, uri, deadline) do
        {:ok, conn} -> {:halt, {:ok, conn}}
        {:error, %Mint.TransportError{reason: :timeout}} -> {:halt, {:error, :timeout}}
        {:error, _reason} -> {:cont, error}
      end
    end)
  end

  # Connects to the validated IP; the hostname is only used for the Host header,
  # SNI and certificate verification, so it is not resolved a second time.
  defp connect_to_ip(scheme, ip, uri, deadline) do
    case remaining_time(deadline) do
      0 ->
        {:error, %Mint.TransportError{reason: :timeout}}

      timeout ->
        Mint.HTTP.connect(scheme, ip, uri.port,
          hostname: uri.host,
          mode: :passive,
          protocols: [:http1],
          transport_opts: transport_opts(scheme, ip, uri.host, timeout)
        )
    end
  end

  # Only use the address family of the validated IP, otherwise Mint retries
  # with the other family and the full timeout again.
  defp transport_opts(scheme, ip, host, timeout) do
    opts = [timeout: timeout, inet4: tuple_size(ip) == 4, inet6: tuple_size(ip) == 8]

    # SNI must not contain IP literals (RFC 6066)
    case {scheme, ip_literal(host)} do
      {:https, {:ok, _ip}} -> Keyword.put(opts, :server_name_indication, :disable)
      _ -> opts
    end
  end

  # Mint does not bracket IPv6 literals in the Host header
  defp host_header(%URI{host: host, port: port, scheme: scheme}) do
    host =
      case ip_literal(host) do
        {:ok, ip} when tuple_size(ip) == 8 -> "[#{host}]"
        _ -> host
      end

    if port == URI.default_port(scheme), do: host, else: "#{host}:#{port}"
  end

  defp request_target(%URI{path: path, query: query}) do
    path = if path in [nil, ""], do: "/", else: path
    if query, do: path <> "?" <> query, else: path
  end

  defp receive_response(conn, ref, acc, deadline, opts) do
    with timeout when timeout > 0 <- remaining_time(deadline),
         {:ok, conn, responses} <- Mint.HTTP.recv(conn, 0, timeout),
         {:cont, acc} <-
           Enum.reduce_while(responses, {:cont, acc}, &handle_mint_response(&1, &2, ref, opts)),
         :ok <- check_received_bytes(conn, opts) do
      receive_response(conn, ref, acc, deadline, opts)
    else
      {:done, {status, headers, body, _size}} ->
        {:ok, {status, headers, IO.iodata_to_binary(body)}}

      0 ->
        {:error, :timeout}

      {:error, :response_too_large} ->
        {:error, :response_too_large}

      {:error, _conn, %Mint.TransportError{reason: :timeout}, _responses} ->
        {:error, :timeout}

      {:error, _conn, reason, _responses} ->
        {:error, reason}
    end
  end

  # The body size is capped in handle_mint_response/4, but Mint buffers
  # headers without a limit
  defp check_received_bytes(conn, opts) do
    if received_bytes(conn) > opts[:max_body_size] + @max_overhead_size,
      do: {:error, :response_too_large},
      else: :ok
  end

  defp handle_mint_response(
         {:status, ref, status},
         {:cont, {_, headers, body, size}},
         ref,
         _opts
       ),
       do: {:cont, {:cont, {status, headers, body, size}}}

  # Skip informational responses (e.g. 103 Early Hints) before the final one
  defp handle_mint_response(
         {:headers, ref, _headers},
         {:cont, {status, _, body, size}},
         ref,
         _opts
       )
       when status in 100..199,
       do: {:cont, {:cont, {nil, [], body, size}}}

  defp handle_mint_response(
         {:headers, ref, new_headers},
         {:cont, {status, headers, body, size}},
         ref,
         _opts
       ) do
    acc = {status, headers ++ new_headers, body, size}
    # Only the body of successful responses is used, skip reading it otherwise
    if status == 200, do: {:cont, {:cont, acc}}, else: {:halt, {:done, acc}}
  end

  defp handle_mint_response({:data, ref, data}, {:cont, {status, headers, body, size}}, ref, opts) do
    max_body_size = opts[:max_body_size]

    if size + byte_size(data) >= max_body_size do
      data = binary_part(data, 0, max_body_size - size)
      {:halt, {:done, {status, headers, [body, data], max_body_size}}}
    else
      {:cont, {:cont, {status, headers, [body, data], size + byte_size(data)}}}
    end
  end

  defp handle_mint_response({:done, ref}, {:cont, acc}, ref, _opts), do: {:halt, {:done, acc}}
  defp handle_mint_response(_response, acc, _ref, _opts), do: {:cont, acc}

  defp received_bytes(conn) do
    socket = Mint.HTTP.get_socket(conn)

    stats =
      if is_port(socket),
        do: :inet.getstat(socket, [:recv_oct]),
        else: :ssl.getstat(socket, [:recv_oct])

    case stats do
      {:ok, [recv_oct: bytes]} -> bytes
      _ -> 0
    end
  end

  defp remaining_time(deadline), do: max(deadline - System.monotonic_time(:millisecond), 0)

  defp handle_parsing({:ok, parsed_document}) do
    {
      :ok,
      title: extract_title(parsed_document),
      description: extract_description(parsed_document),
      img_preview_url: extract_img_preview(parsed_document)
    }
  end

  defp handle_parsing({_, _}) do
    {:error, @empty_preview}
  end

  defp extract_description(parsed_document) do
    parsed_document
    |> Floki.find("meta[name=description]")
    |> Floki.attribute("content")
    |> List.first("")
    |> String.slice(0, 300)
  end

  defp extract_title(parsed_document) do
    parsed_document
    |> Floki.find("title")
    |> Floki.text()
    |> String.slice(0, 300)
  end

  defp extract_img_preview(parsed_document) do
    parsed_document
    |> Floki.find("meta[property='og:image']")
    |> Floki.attribute("content")
    |> List.first() || ""
  end
end
