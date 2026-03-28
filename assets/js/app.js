import { Modal, Tooltip } from "bootstrap"
import Sortable from 'sortablejs';
import { setIdeaLabelBackgroundColor } from "./label";
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

const FLASH_DISMISS_DELAY_MS = 5000;
const FLASH_FADE_DURATION_MS = 500;

Hooks.AutoDismissFlash = {
  mounted() {
    // Handle localStorage cleanup for missing brainstorming flash messages
    const missingId = this.el.dataset.brainstormingId;
    if (missingId) {
      try {
        const recentBrainstormings = JSON.parse(localStorage.getItem('brainstormings') || '{}');
        delete recentBrainstormings[missingId];
        localStorage.setItem('brainstormings', JSON.stringify(recentBrainstormings));
      } catch (_) {
        // Ignore malformed localStorage data
      }
    }

    this._startTimer();

    // Close button handler
    const closeButton = this.el.querySelector('[data-dismiss-flash]');
    if (closeButton) {
      closeButton.addEventListener('click', () => this._dismiss());
    }

    // Pause timer on hover
    this.el.addEventListener('mouseenter', () => this._pauseTimer());
    this.el.addEventListener('mouseleave', () => this._resumeTimer());
  },

  updated() {
    // Reset timer when flash content changes (LiveView DOM patching)
    this._clearTimer();
    this.el.classList.remove('flash-fade-out');
    this._startTimer();
  },

  destroyed() {
    this._clearTimer();
  },

  _startTimer() {
    this._startedAt = Date.now();
    this._remaining = FLASH_DISMISS_DELAY_MS;
    this._timer = setTimeout(() => this._dismiss(), this._remaining);
  },

  _clearTimer() {
    if (this._timer) {
      clearTimeout(this._timer);
      this._timer = null;
    }
    if (this._fadeTimer) {
      clearTimeout(this._fadeTimer);
      this._fadeTimer = null;
    }
  },

  _pauseTimer() {
    if (this._timer) {
      clearTimeout(this._timer);
      this._timer = null;
      this._remaining = Math.max(0, this._remaining - (Date.now() - this._startedAt));
    }
  },

  _resumeTimer() {
    if (this._remaining != null && !this._timer) {
      this._startedAt = Date.now();
      this._timer = setTimeout(() => this._dismiss(), this._remaining);
    }
  },

  _dismiss() {
    this._clearTimer();
    this.el.classList.add('flash-fade-out');
    const ALLOWED_KINDS = ['info', 'error'];
    this._fadeTimer = setTimeout(() => {
      const kind = this.el.dataset.flashKind;
      if (ALLOWED_KINDS.includes(kind)) {
        this.pushEvent('lv:clear-flash', { key: kind });
      }
    }, FLASH_FADE_DURATION_MS);
  }
};

Hooks.LanesScrollIndicator = {
  mounted() {
    this.scrollContainer = this.el.querySelector('.lanes-container');
    this.leftArrow = this.el.querySelector('#lanes-scroll-left');
    this.rightArrow = this.el.querySelector('#lanes-scroll-right');

    this.getColumnWidth = () => {
      const col = this.scrollContainer.querySelector('[class*="col-"]');
      return col ? col.offsetWidth : 300;
    };

    this.updateIndicators = () => {
      const { scrollLeft, scrollWidth, clientWidth } = this.scrollContainer;
      const canScrollLeft = scrollLeft > 0;
      const canScrollRight = scrollLeft + clientWidth < scrollWidth - 1;

      this.leftArrow.classList.toggle('visible', canScrollLeft);
      this.rightArrow.classList.toggle('visible', canScrollRight);
    };

    this.leftArrow.addEventListener('click', () => {
      this.scrollContainer.scrollBy({ left: -this.getColumnWidth(), behavior: 'smooth' });
    });

    this.rightArrow.addEventListener('click', () => {
      this.scrollContainer.scrollBy({ left: this.getColumnWidth(), behavior: 'smooth' });
    });

    this.scrollContainer.addEventListener('scroll', this.updateIndicators);
    this.resizeObserver = new ResizeObserver(this.updateIndicators);
    this.resizeObserver.observe(this.scrollContainer);

    this.updateIndicators();
  },
  updated() {
    this.updateIndicators();
  },
  destroyed() {
    this.resizeObserver.disconnect();
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