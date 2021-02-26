// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "../css/app.scss"

import '@popperjs/core'
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
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

Hooks.CopyBrainstormingLinkButton = {
  mounted() {
    this.el.addEventListener('click', (event) => {
      document.querySelector("#brainstorming-link").select()
      // does not work in safari - apparently there is no single function that works everywhere. Of course.
      document.execCommand('copy')
    })
  }
}

Hooks.ShareBrainstormingLinkButton = {
  mounted() {
    this.el.addEventListener('click', (event) => {
        if(navigator.share) {
          navigator.share({
            title: 'Mindwendel Brainstorming',
            text: 'Join my brainstorming',
            url: document.getElementById("brainstorming-link").value
          })
        } else {
          document.getElementById("brainstorming-sharing-link-block").classList.toggle('invisible');
        }
    })
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
    this.el.querySelector(".phx-modal-close").addEventListener('click', hideModal)
    this.el.querySelector(".form-cancel").addEventListener('click', hideModal)
    this.el.addEventListener('keyup', (keyEvent) => {
      if (keyEvent.key === 'Escape') {
        // This will tell the "#modal" div to send a "close" event to the server
        this.pushEventTo("#modal", "close")
        hideModal()

        // You could also just press the button ;-), i.e. this.el.querySelector(".phx-modal-close").click()
      }
    })
    
    window.addEventListener('popstate', () => {
      hideModal()
      // To avoid multiple registers
      window.removeEventListener('popstate', hideModal)
    })
  },
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