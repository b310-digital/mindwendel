import QRCodeStyling from "qr-code-styling";

const buildQrCodeOptions = (qrCodeUrl) => ({
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
});

export const appendQrCode = (qrCodeCanvasElement) => {
  const qrCodeUrl = qrCodeCanvasElement.getAttribute("data-qr-code-url")

  const qrCodeOptions = buildQrCodeOptions(qrCodeUrl)
  const qrCode = new QRCodeStyling(qrCodeOptions)

  qrCode.append(qrCodeCanvasElement);
}

export const initQrDownload = (button) => {
  const qrCodeUrl = button.getAttribute("data-qr-code-url");
  const qrCodeFilename = button.getAttribute("data-qr-code-filename") || qrCodeUrl || "qrcode";
  const qrCodeFileExtension = button.getAttribute("data-qr-code-file-extension") || "png";

  const qrCodeOptions = buildQrCodeOptions(qrCodeUrl)
  const qrCode = new QRCodeStyling(qrCodeOptions)

  const clickEventListener = () => {
    qrCode.download({ name: qrCodeFilename, extension: qrCodeFileExtension })
      .then() // Do nothing
      .catch(err => { console.log(`Error: ${err}`) })
  };

  button && button.addEventListener('click', clickEventListener);
  return clickEventListener;
}
