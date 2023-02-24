import { Modal } from "bootstrap"

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import deps with the dep name or local files with a relative path, for example:
//
//     import {Socket} from "phoenix"
//     import socket from "./socket"
//

import "phoenix_html"
import {Socket} from "phoenix"
import NProgress from "nprogress"
import {LiveSocket} from "phoenix_live_view"
import QRCodeStyling from "qr-code-styling";
import ClipboardJS from "clipboard"
import {buildQrCodeOptions} from "./qrCodeUtils.js"
import "./column_setup.js"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

Hooks.CopyBrainstormingLinkButton = {
  mounted() {
    new ClipboardJS(this.el);
  }
}

Hooks.NativeSharingButton = {
  mounted() {
    const shareData = {
      title: this.el.getAttribute(`data-native-sharing-button-share-data-title`) || 'Mindwendel Brainstorming',
      text: this.el.getAttribute(`data-native-sharing-button-share-data-text`) || 'Join my brainstorming',
      url: this.el.getAttribute(`data-native-sharing-button-share-data-url`) || document.getElementById("brainstorming-link").value
    }
     
    if (navigator.share) {
      this.el.addEventListener('click', (event) => {
        navigator.share(shareData)
        .then() // Do nothing
        .catch(err => { console.log(`Error: ${err}`) }) 
      })
    }
  }
}

Hooks.Modal = {
  mounted() {
    // The live component gets removed by using push_redirect on the server (see form_component.ex).
    // However, this confuses the modal js from bootstrap, because it does not know yet it got closed which results in UX bugs.
    // Therefore, we try to close the modal during a callback to essentially sync bootstrap modal state with the live view.
    // An alternative would be, to close the modal in JS and use pushEvent from here to continue execution on the server.
    // See https://fullstackphoenix.com/tutorials/create-a-reusable-modal-with-liveview-component
    const modal = new Modal(this.el, { backdrop: 'static', keyboard: false })
    modal.show()
    
    const hideModal = () => modal && modal.hide()
    
    this.el.addEventListener('submit', hideModal)

    const formCancelElement = this.el.querySelector(".form-cancel")
    formCancelElement && formCancelElement.addEventListener('click', hideModal)
    
    const phxModalCloseElement = this.el.querySelector(".phx-modal-close")
    phxModalCloseElement && phxModalCloseElement.addEventListener('click', hideModal)
    
    this.el.addEventListener('keyup', (keyEvent) => {
      if (keyEvent.key === 'Escape') {
        // This will tell the "#modal" div to send a "close" event to the server
        this.pushEventTo("#modal", "close")
        hideModal()
      }
    })
    
    window.addEventListener('popstate', () => {
      hideModal()
      // To avoid multiple registers
      window.removeEventListener('popstate', hideModal)
    })
  }
}

Hooks.QrCodeCanvas = {
  mounted() {
    const qrCodeCanvasElement = this.el
    const qrCodeUrl = qrCodeCanvasElement.getAttribute("data-qr-code-url")
    
    const qrCodeOptions = buildQrCodeOptions(qrCodeUrl)
    const qrCode = new QRCodeStyling(qrCodeOptions)
            
    qrCode.append(qrCodeCanvasElement);
  }
}

Hooks.QrCodeDownloadButton = {
  mounted() {
    const qrCodeUrl = this.el.getAttribute("data-qr-code-url");
    const qrCodeFilename = this.el.getAttribute("data-qr-code-filename") || qrCodeUrl || "qrcode";
    const qrCodeFileExtension = this.el.getAttribute("data-qr-code-file-extension") || "png";
    
    const qrCodeOptions = buildQrCodeOptions(qrCodeUrl)
    const qrCode = new QRCodeStyling(qrCodeOptions)
    
    this.el && this.el.addEventListener('click', () => {
      qrCode.download({ name: qrCodeFilename, extension: qrCodeFileExtension })
        .then() // Do nothing
        .catch(err => { console.log(`Error: ${err}`) }) 
    })
  }
}

let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, params: {_csrf_token: csrfToken}})

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

