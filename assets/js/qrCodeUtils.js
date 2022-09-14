export const buildQrCodeOptions = (qrCodeUrl) => ({
  backgroundOptions: {
    color: "#fff",
  },
  cornersDotOptions: {
    type: 'dot'
  },
  cornersSquareOptions: {
    type: 'square'
  },
  dotsOptions: {
    color: '#000000',
    type: "dots",
  },
  imageOptions: {
    crossOrigin: "anonymous",
    margin: 20,
  },
  data: qrCodeUrl || "",
  height: 300,
  type: "svg",
  width: 300
})
