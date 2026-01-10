import { Controller } from "@hotwired/stimulus"
import { nextFrame } from "helpers/timing_helpers"
import { isMobile } from "helpers/platform_helpers"

export default class extends Controller {
  static targets = ["item", "input"]
  static values = {
    selectionAttribute: { type: String, default: "aria-selected" },
    focusOnSelection: { type: Boolean, default: true },
    actionableItems: { type: Boolean, default: false },
    autoSelect: { type: Boolean, default: true },
    autoScroll: { type: Boolean, default: true }
  }

  static get shouldLoad() {
    return !isMobile()
  }

  connect() {
    if (this.autoSelectValue) {
      this.reset()
    }
  }

  reset(event) {
    this.selectFirst()
  }

  navigate(event) {
    const handlers = {
      ArrowDown: () => this.#selectNext(),
      ArrowUp: () => this.#selectPrevious(),
      Enter: () => this.#clickCurrentItem(event)
    }

    if (handlers[event.key]) {
      handlers[event.key]()
      event.preventDefault()
    }
  }

  select({ target }) {
    this.selectItem(target, true)
  }

  hoverSelect({ currentTarget }) {
    this.selectItem(currentTarget)
  }

  selectFirst() {
    const firstVisible = this.#visibleItems[0]
    if (firstVisible) this.selectItem(firstVisible)
  }

  selectLast() {
    const lastVisible = this.#visibleItems[this.#visibleItems.length - 1]
    if (lastVisible) this.selectItem(lastVisible)
  }

  async selectItem(item, skipFocus = false) {
    this.#clearSelection()
    item.setAttribute(this.selectionAttributeValue, "true")
    this.currentItem = item
    this.#refreshActiveDescendant()

    await nextFrame()

    if (this.autoScrollValue) {
      this.currentItem.scrollIntoView({ block: "nearest", inline: "nearest" })
    }

    if (!skipFocus && this.focusOnSelectionValue) {
      this.currentItem.focus({ preventScroll: !this.autoScrollValue })
    }
  }

  #clearSelection() {
    for (const item of this.itemTargets) {
      item.removeAttribute(this.selectionAttributeValue)
    }
  }

  #refreshActiveDescendant() {
    const id = this.currentItem?.getAttribute("id")
    if (this.hasInputTarget && id) {
      this.inputTarget.setAttribute("aria-activedescendant", id)
    }
  }

  #selectPrevious() {
    const index = this.#visibleItems.indexOf(this.currentItem)
    if (index > 0) {
      this.selectItem(this.#visibleItems[index - 1])
    }
  }

  #selectNext() {
    const index = this.#visibleItems.indexOf(this.currentItem)
    if (index >= 0 && index < this.#visibleItems.length - 1) {
      this.selectItem(this.#visibleItems[index + 1])
    }
  }

  #clickCurrentItem(event) {
    if (this.actionableItemsValue && this.currentItem && this.#visibleItems.length) {
      const clickableElement = this.currentItem.querySelector("a,button") || this.currentItem
      clickableElement.click()
      event.preventDefault()
    }
  }

  get #visibleItems() {
    return this.itemTargets.filter(item => {
      return item.checkVisibility && item.checkVisibility() && !item.hidden
    })
  }
}
