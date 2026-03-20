defmodule MindwendelWeb.IdeaLive.FormComponentTest do
  use ExUnit.Case, async: true

  alias MindwendelWeb.IdeaLive.FormComponent

  @fixtures_dir Path.join([__DIR__, "..", "..", "..", "fixtures"])

  describe "detect_mime_type/1" do
    test "detects PNG from a real image file" do
      path = Path.join(@fixtures_dir, "test_image.png")
      assert FormComponent.detect_mime_type(path) == "image/png"
    end

    test "returns nil for SVG file (malicious)" do
      path = Path.join(@fixtures_dir, "test_malicious.svg")
      assert FormComponent.detect_mime_type(path) == nil
    end

    test "detects JPEG from magic bytes" do
      path = write_tmp("jpeg", <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10>>)
      assert FormComponent.detect_mime_type(path) == "image/jpeg"
    end

    test "detects GIF from magic bytes" do
      path = write_tmp("gif", <<0x47, 0x49, 0x46, 0x38, 0x39, 0x61>>)
      assert FormComponent.detect_mime_type(path) == "image/gif"
    end

    test "detects PDF from magic bytes" do
      path = write_tmp("pdf", <<0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E>>)
      assert FormComponent.detect_mime_type(path) == "application/pdf"
    end

    test "returns nil for HTML content" do
      path = write_tmp("html", "<html><body><script>alert(1)</script></body></html>")
      assert FormComponent.detect_mime_type(path) == nil
    end

    test "returns nil for empty file" do
      path = write_tmp("empty", "")
      assert FormComponent.detect_mime_type(path) == nil
    end

    test "returns nil for nonexistent file" do
      assert FormComponent.detect_mime_type("/tmp/nonexistent_file") == nil
    end
  end

  defp write_tmp(suffix, content) do
    path = Path.join(System.tmp_dir!(), "mime_test_#{suffix}")
    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
