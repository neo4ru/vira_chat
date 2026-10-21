export default {
  mounted() {
    this.card = this.el.querySelector("[data-call-card]")
    this.hideTimer = null
    this._bindTapToReveal()
  },

  updated() {
    this.card = this.el.querySelector("[data-call-card]")
  },

  destroyed() {
    clearTimeout(this.hideTimer)
  },

  _bindTapToReveal() {
    const isVideoInCall = () =>
      this.el.dataset.state === "in_call" && this.el.dataset.type === "video"

    const reveal = () => {
      if (!isVideoInCall() || !this.card) return
      this.card.classList.remove("opacity-0", "pointer-events-none")
      clearTimeout(this.hideTimer)
      this.hideTimer = setTimeout(() => {
        if (isVideoInCall()) {
          this.card.classList.add("opacity-0", "pointer-events-none")
        }
      }, 3000)
    }

    this.el.addEventListener("click", reveal)
    this.el.addEventListener("mousemove", reveal)
  },
}