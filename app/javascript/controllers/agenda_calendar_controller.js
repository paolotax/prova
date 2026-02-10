import { Controller } from "@hotwired/stimulus"
import { get } from "@rails/request.js"

export default class extends Controller {
  static targets = ["weeksContainer", "sentinelTop", "sentinelBottom", "currentWeek", "oggiButton"]
  static values = { giorno: String }

  connect() {
    this.loadingTop = false
    this.loadingBottom = false
    this.setupObservers()
    this.scrollToToday()
  }

  disconnect() {
    if (this.topObserver) this.topObserver.disconnect()
    if (this.bottomObserver) this.bottomObserver.disconnect()
    if (this.todayObserver) this.todayObserver.disconnect()
  }

  scrollToToday() {
    if (this.hasCurrentWeekTarget) {
      this.currentWeekTarget.scrollIntoView({ behavior: "smooth", block: "center" })
    }
  }

  setupObservers() {
    this.topObserver = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && !this.loadingTop) {
          this.loadWeeks("prepend")
        }
      },
      { rootMargin: "200px 0px 0px 0px" }
    )

    this.bottomObserver = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && !this.loadingBottom) {
          this.loadWeeks("append")
        }
      },
      { rootMargin: "0px 0px 200px 0px" }
    )

    if (this.hasSentinelTopTarget) this.topObserver.observe(this.sentinelTopTarget)
    if (this.hasSentinelBottomTarget) this.bottomObserver.observe(this.sentinelBottomTarget)

    // Today button visibility
    if (this.hasCurrentWeekTarget) {
      this.todayObserver = new IntersectionObserver(
        (entries) => {
          if (this.hasOggiButtonTarget) {
            this.oggiButtonTarget.style.display = entries[0].isIntersecting ? "none" : ""
          }
        },
        { threshold: 0.1 }
      )
      this.todayObserver.observe(this.currentWeekTarget)
    }
  }

  async loadWeeks(direction) {
    const flag = direction === "prepend" ? "loadingTop" : "loadingBottom"
    if (this[flag]) return
    this[flag] = true

    const weekElements = this.weeksContainerTarget.querySelectorAll("[data-week]")
    if (weekElements.length === 0) {
      this[flag] = false
      return
    }

    let referenceDate
    if (direction === "prepend") {
      referenceDate = weekElements[0].dataset.week
      const date = new Date(referenceDate + "T00:00:00")
      date.setDate(date.getDate() - 14)
      referenceDate = date.toISOString().slice(0, 10)
    } else {
      const lastWeek = weekElements[weekElements.length - 1]
      referenceDate = lastWeek.dataset.week
      const date = new Date(referenceDate + "T00:00:00")
      date.setDate(date.getDate() + 7)
      referenceDate = date.toISOString().slice(0, 10)
    }

    const currentPath = window.location.pathname
    const accountMatch = currentPath.match(/^(\/[0-9a-f-]{36})/)
    const prefix = accountMatch ? accountMatch[1] : ""
    const url = `${prefix}/agenda?giorno=${referenceDate}&weeks=2&direction=${direction}`

    try {
      const previousScrollHeight = this.weeksContainerTarget.scrollHeight

      const response = await get(url, { responseKind: "turbo-stream" })

      if (response.ok && direction === "prepend") {
        requestAnimationFrame(() => {
          const newScrollHeight = this.weeksContainerTarget.scrollHeight
          const heightDiff = newScrollHeight - previousScrollHeight
          window.scrollBy(0, heightDiff)
        })
      }
    } catch (error) {
      console.error(`Error loading ${direction} weeks:`, error)
    } finally {
      this[flag] = false
      // Re-observe sentinel to reset IntersectionObserver state.
      // Without this, the observer won't fire again if the sentinel
      // was already visible when the load completed.
      this.reobserveSentinel(direction)
    }
  }

  reobserveSentinel(direction) {
    if (direction === "prepend" && this.hasSentinelTopTarget) {
      this.topObserver.unobserve(this.sentinelTopTarget)
      this.topObserver.observe(this.sentinelTopTarget)
    } else if (direction === "append" && this.hasSentinelBottomTarget) {
      this.bottomObserver.unobserve(this.sentinelBottomTarget)
      this.bottomObserver.observe(this.sentinelBottomTarget)
    }
  }
}
