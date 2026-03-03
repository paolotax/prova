import { Controller } from "@hotwired/stimulus"
import { nextFrame, debounce } from "helpers/timing_helpers";

export default class extends Controller {
  static classes = [ "collapsed", "expanded", "noTransitions", "titleNotVisible" ]
  static targets = [ "column", "button", "title", "maybeColumn" ]
  static values = {
    board: String,
    desktopBreakpoint: { type: String, default: "(min-width: 640px)" },
    exclusive: { type: Boolean, default: true }
  }

  initialize() {
    this.restoreState = debounce(this.restoreState.bind(this), 10)
  }

  async connect() {
    await this.#restoreColumnsDisablingTransitions()
    this.#setupIntersectionObserver()

    this.mediaQuery = window.matchMedia(this.desktopBreakpointValue)
    this.handleDesktop = this.#handleDesktop.bind(this)
    this.mediaQuery.addEventListener("change", this.handleDesktop)
    this.handleDesktop(this.mediaQuery)
  }

  disconnect() {
    if (this._intersectionObserver) {
      this._intersectionObserver.disconnect()
      this._intersectionObserver = null
    }
    this.mediaQuery.removeEventListener("change", this.handleDesktop)
  }

  toggle({ target }) {
    const column = target.closest('[data-collapsible-columns-target~="column"]')
    this.#toggleColumn(column);
  }

  preventToggle(event) {
    if (event.target.hasAttribute("data-collapsible-columns-target") && event.detail.attributeName === "class") {
      event.preventDefault()
    }
  }

  async restoreState(event) {
    await nextFrame()
    await this.#restoreColumnsDisablingTransitions()
  }

  focusOnColumn({ target }) {
    if (this.#isDesktop && this.#isCollapsed(target)) {
      if (this.exclusiveValue) this.#collapseAllExcept(target)
      this.#expand(target)
    }
  }

  async #restoreColumnsDisablingTransitions() {
    this.#disableTransitions()
    this.#restoreColumns()

    await nextFrame()
    this.#enableTransitions()
  }

  #disableTransitions() {
    this.element.classList.add(this.noTransitionsClass)
  }

  #enableTransitions() {
    this.element.classList.remove(this.noTransitionsClass)
  }

  #toggleColumn(column) {
    if (this.exclusiveValue) this.#collapseAllExcept(column)

    if (this.#isCollapsed(column)) {
      this.#expand(column)
    } else {
      this.#collapse(column)
    }
  }

  #collapseAllExcept(clickedColumn) {
    const maybe = this.hasMaybeColumnTarget ? this.maybeColumnTarget : null
    const columns = this.#isDesktop && maybe ? this.columnTargets.filter(c => c !== maybe) : this.columnTargets

    columns.forEach(column => {
      if (column !== clickedColumn) {
        this.#collapse(column)
      }
    })
  }

  #isCollapsed(column) {
    return column.classList.contains(this.collapsedClass)
  }

  #collapse(column, saveState = true) {
    this.#buttonFor(column)?.setAttribute("aria-expanded", "false")
    column.classList.remove(this.expandedClass)
    column.classList.add(this.collapsedClass)

    if (saveState) {
      const key = this.#localStorageKeyFor(column)
      localStorage.setItem(key, "collapsed")
    }
  }

  #expand(column, saveState = true) {
    this.#buttonFor(column)?.setAttribute("aria-expanded", "true")
    column.classList.remove(this.collapsedClass)
    column.classList.add(this.expandedClass)

    if (saveState) {
      const key = this.#localStorageKeyFor(column)
      localStorage.setItem(key, "expanded")
    }

    if (window.matchMedia('(max-width: 639px)').matches) {
      column.scrollIntoView({ behavior: "smooth", inline: "center" })
    }
  }

  #buttonFor(column) {
    return this.buttonTargets.find(button => column.contains(button))
  }

  #restoreColumns() {
    this.columnTargets.forEach(column => {
      this.#restoreColumn(column)
    })
  }

  #restoreColumn(column) {
    const key = this.#localStorageKeyFor(column)
    const saved = localStorage.getItem(key)

    if (saved === "expanded") {
      if (this.exclusiveValue) this.#collapseAllExcept(column)
      this.#expand(column, false)
    } else if (saved === "collapsed") {
      this.#collapse(column, false)
    }
  }

  #localStorageKeyFor(column) {
    const name = column.dataset.columnName || column.getAttribute("id") || ""
    return `columns-${this.boardValue}-${name}`
  }

  #setupIntersectionObserver() {
    if (typeof IntersectionObserver === "undefined") return
    if (this._intersectionObserver) this._intersectionObserver.disconnect()

    this._intersectionObserver = new IntersectionObserver(entries => {
      entries.forEach(entry => {
        const title = entry.target
        const column = title.closest(".cards")

        if (!column) return

        const offscreen = entry.intersectionRatio === 0
        column.classList.toggle(this.titleNotVisibleClass, offscreen)
      })
    }, { threshold: [0] })

    this.titleTargets.forEach(title => this._intersectionObserver.observe(title))
  }

  get #isDesktop() {
    return this.mediaQuery?.matches
  }

  #handleDesktop() {
    this.#isDesktop ? this.#handleDesktopMode() : this.#handleMobileMode()
  }

  async #handleDesktopMode() {
    if (!this.hasMaybeColumnTarget) return

    this.#expand(this.maybeColumnTarget, false)
    this.#maybeButton.setAttribute("disabled", true)
  }

  #handleMobileMode() {
    if (!this.hasMaybeColumnTarget) return

    this.#maybeButton.removeAttribute("disabled")

    const expandedColumn = this.columnTargets.find(column => column !== this.maybeColumnTarget && !this.#isCollapsed(column))

    if (expandedColumn) {
      this.#collapseAllExcept(expandedColumn)
    } else {
      this.#collapseAllExcept(this.maybeColumnTarget)
    }
  }

  get #maybeButton() {
    return this.maybeColumnTarget.querySelector('[data-collapsible-columns-target="button"]')
  }
}
