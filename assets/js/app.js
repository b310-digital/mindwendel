import { Modal, Tooltip } from "bootstrap"
import Sortable from 'sortablejs';
import { setIdeaLabelBackgroundColor } from "./label"
import { getRelativeTimeString } from "./timeUtils"
// activate all tooltips:
const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]');
[...tooltipTriggerList].map(tooltipTriggerEl => new Tooltip(tooltipTriggerEl));

const sortBrainstormingsByLastAccessedAt = (brainstormings, sliceMax = 10) => {
  return Object.values(brainstormings).sort((a, b) => new Date(b.last_accessed_at) - new Date(a.last_accessed_at)).slice(0, sliceMax)
}

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
import { initShareButtonClickHandler } from "./shareUtils.js"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}
const sortables = [];

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

Hooks.CopyBrainstormingLinkButton = {
  mounted() {
    new ClipboardJS(this.el);
  }
}

let refShareClickListenerFunction;
let refShareButton;

Hooks.NativeSharingButton = {
  mounted() {
    refShareButton = this.el;
    refShareClickListenerFunction = initShareButtonClickHandler(refShareButton);
  },
  updated() {
    refShareButton.removeEventListener("click", refShareClickListenerFunction);
    refShareButton = this.el;
    refShareClickListenerFunction = initShareButtonClickHandler(refShareButton);
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

Hooks.TransferLocalStorageBrainstormings = {
  mounted() {
    const recentBrainstormings = JSON.parse(localStorage.getItem('brainstormings') || '{}');
    const lastSortedBrainstormings = sortBrainstormingsByLastAccessedAt(recentBrainstormings, 5)
    this.pushEventTo(this.el, "brainstormings_from_local_storage", lastSortedBrainstormings)
  }
}

Hooks.StoreRecentBrainstorming = {
  mounted() {
    const brainstormingId = this.el.dataset.id;
    const recentBrainstormings = JSON.parse(localStorage.getItem('brainstormings') || '{}');
    
    recentBrainstormings[brainstormingId] = {
      id: brainstormingId,
      admin_url_id: this.el.dataset.adminUrlId || recentBrainstormings?.brainstormingId?.admin_url_id,
      name: this.el.dataset.name,
      last_accessed_at: this.el.dataset.lastAccessedAt
    }
    localStorage.setItem('brainstormings', JSON.stringify(recentBrainstormings));
    const lastSortedBrainstormings = sortBrainstormingsByLastAccessedAt(recentBrainstormings)
    this.pushEventTo(this.el,"brainstormings_from_local_storage", lastSortedBrainstormings)
  }
};

Hooks.RemoveMissingBrainstorming = {
  mounted() {
    const missingId = this.el.dataset.brainstormingId;
    if (missingId) {
      const recentBrainstormings = JSON.parse(localStorage.getItem('brainstormings') || '{}');
      delete recentBrainstormings[missingId]
      localStorage.setItem('brainstormings', JSON.stringify(recentBrainstormings));
    }
  }
};

// The brainstorming secret from the url ("#123") is added as well to the socket. The secret is not available on the server side by default.
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