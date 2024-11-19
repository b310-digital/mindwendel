import { Modal, Tooltip } from "bootstrap"
import Sortable from 'sortablejs';
import { setIdeaLabelBackgroundColor } from "./label"

// activate all tooltips:
const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]');
[...tooltipTriggerList].map(tooltipTriggerEl => new Tooltip(tooltipTriggerEl));

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
import { Socket } from "phoenix"
import NProgress from "nprogress"
import { LiveSocket } from "phoenix_live_view"
import ClipboardJS from "clipboard"
import { appendQrCode, initQrDownload } from "./qrCodeUtils.js"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}
const sortables = [];

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
      url: document.getElementById("data-native-sharing-button-share-data-url") || document.getElementById("brainstorming-link-input-readonly").value
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

// see https://github.com/drag-drop-touch-js/dragdroptouch for mobile support
Hooks.Sortable = {
  mounted(){
    const sortable = new Sortable(this.el, {
      group: { put: true, pull: true },
      disabled: this.el.dataset.sortableEnabled !== 'true',
      delayOnTouchOnly: true,
      delay: 50,
      onEnd: (event) => {
        this.pushEventTo(this.el, "change_position", {
          id: event.item.dataset.id,
          brainstorming_id: event.item.dataset.brainstormingId,
          lane_id: event.to.dataset.laneId || event.item.dataset.laneId,
          // on the server, positions start with 1 not 0
          new_position: event.newIndex + 1,
          old_position: event.oldIndex + 1
        })
      }
    })
    sortables.push(sortable);
  },
  updated(){
    sortables.forEach((sortable) => sortable.option("disabled", this.el.dataset.sortableEnabled !== 'true'));
  }
}

Hooks.Modal = {
  mounted() {
    const modal = new Modal(this.el, { backdrop: 'static', keyboard: false });
    const closeModal = () => modal && modal.hide();

    modal.show();

    window.addEventListener('mindwendel:hide-modal', closeModal);
  }
}

Hooks.QrCodeCanvas = {
  mounted() {
    appendQrCode(this.el);
  },
  updated() {
    appendQrCode(this.el);
  }
}

// References are needed to properly handle live view changes and prevent callbacks being fired twice
let refQrClickListenerFunction;
let refQrCodeDownloadButton;

Hooks.QrCodeDownloadButton = {
  mounted() {
    refQrCodeDownloadButton = this.el;
    refQrClickListenerFunction = initQrDownload(refQrCodeDownloadButton);
  },
  updated() {
    refQrCodeDownloadButton.removeEventListener("click", refQrClickListenerFunction);
    refQrCodeDownloadButton = this.el;
    refQrClickListenerFunction = initQrDownload(refQrCodeDownloadButton);
  }
}

Hooks.SetIdeaLabelColor = {
  mounted() {
    const color = this.el.getAttribute("data-color");
    this.el.style.color = color;
  },
  updated() {
    const color = this.el.getAttribute("data-color");
    this.el.style.color = color;
  }
};

Hooks.SetIdeaLabelBackgroundColor = {
  mounted() {
    setIdeaLabelBackgroundColor(this.el)
  },
  updated() {
    setIdeaLabelBackgroundColor(this.el)
  }
};

let liveSocket = new LiveSocket("/live", Socket, { 
  hooks: Hooks, params: { _csrf_token: csrfToken, adminSecret: window.location.hash.substring(1) }
})

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