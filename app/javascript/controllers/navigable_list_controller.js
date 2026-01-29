import { Controller } from "@hotwired/stimulus"
import { nextFrame } from "helpers/timing_helpers"
import { isMobile } from "helpers/platform_helpers"

export default class extends Controller {
  static targets = [ "item", "input" ]
  static values = {
    reverseOrder: { type: Boolean, default: false },
    selectionAttribute: { type: String, default: "aria-selected" },
    focusOnSelection: { type: Boolean, default: true },
    actionableItems: { type: Boolean, default: false },
    reverseNavigation: { type: Boolean, default: false },
    supportsHorizontalNavigation: { type: Boolean, default: true },
    supportsVerticalNavigation: { type: Boolean, default: true },
    hasNestedNavigation: { type: Boolean, default: false },
    preventHandledKeys: { type: Boolean, default: false },
    autoSelect: { type: Boolean, default: true },
    autoScroll: { type: Boolean, default: true },
    onlyActOnFocusedItems: { type: Boolean, default: false }
  }

  // Don't load for mobile devices
  static get shouldLoad() {
    return !isMobile()
  }

  connect() {
    if (this.autoSelectValue) {
      this.reset()
    } else {
      this.#activateManualSelection()
    }
  }

  disconnect() {
    this.#clearSelection()
    this.currentItem = null
  }

  // Actions

  reset(event) {
    if (this.reverseOrderValue) {
      this.selectLast()
    } else {
      this.selectFirst()
    }
  }

  navigate(event) {
    this.#keyHandlers[event.key]?.call(this, event)
  }

  select({ target }) {
    this.selectItem(target, true)
  }

  hoverSelect({ currentTarget }) {
    this.selectItem(currentTarget)
  }

  // Right-click to toggle checkbox selection
  toggleSelection(event) {
    event.preventDefault()
    const item = event.currentTarget
    const checkbox = item.querySelector("input[type=checkbox]")

    if (checkbox && !checkbox.disabled) {
      checkbox.checked = !checkbox.checked
      checkbox.dispatchEvent(new Event('change', { bubbles: true }))
    }
  }

  selectCurrentOrReset(event) {
    if (this.currentItem) {
      this.#setCurrentFrom(this.currentItem)
    } else {
      this.reset()
    }
  }

  selectFirst() {
    this.#setCurrentFrom(this.#visibleItems[0])
  }

  selectLast() {
    this.#setCurrentFrom(this.#visibleItems[this.#visibleItems.length - 1])
  }

  deselectWhenClickingOutside(event) {
    if (this.element.contains(event.target)) {
      return
    }

    this.#clearSelection()
  }

  // Public

  async selectItem(item, skipFocus = false) {
    this.#clearSelection()
    item.setAttribute(this.selectionAttributeValue, "true")
    this.currentItem = item
    this.#refreshActiveDescendant()

    await nextFrame()

    if (this.autoScrollValue) { this.currentItem.scrollIntoView({ block: "nearest", inline: "nearest" }) }

    if (!skipFocus && this.focusOnSelectionValue) { this.currentItem.focus({ preventScroll: !this.autoScrollValue }) }
  }

  isSelected(item) {
    return item === this.currentItem
  }

  // Private

  async #setCurrentFrom(element) {
    const selectedItem = this.#visibleItems.find(item => item.contains(element))

    if (selectedItem) {
      await this.selectItem(selectedItem)
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

  #activateManualSelection() {
    const preselectedItem = this.itemTargets.find(item => item.hasAttribute(this.selectionAttributeValue))
    if (preselectedItem) {
      this.#setCurrentFrom(preselectedItem)
    }
  }

  #selectPrevious() {
    const index = this.#visibleItems.indexOf(this.currentItem)
    if (index > 0) {
      this.#setCurrentFrom(this.#visibleItems[index - 1])
    }
  }

  #selectNext() {
    const index = this.#visibleItems.indexOf(this.currentItem)
    if (index >= 0 && index < this.#visibleItems.length - 1) {
      this.#setCurrentFrom(this.#visibleItems[index + 1])
    }
  }

  #handleArrowKey(event, fn) {
    if (event.shiftKey || event.metaKey || event.ctrlKey) { return }
    fn.call()
    if (this.preventHandledKeysValue) {
      event.preventDefault()
    }
  }

  #clickCurrentItem(event) {
    if (this.actionableItemsValue && this.currentItem && this.#visibleItems.length && this.#isFocusContainedOnNavigableItem) {
      const clickableElement = this.currentItem.querySelector("a,button") || this.currentItem
      clickableElement.click()
      event.preventDefault()
    }
  }

  get #isFocusContainedOnNavigableItem() {
    return !this.onlyActOnFocusedItemsValue || this.itemTargets.some(item => item === document.activeElement || item.contains(document.activeElement))
  }

  #toggleCurrentItem(event) {
    if (this.actionableItemsValue && this.currentItem && this.#visibleItems.length) {
      const toggleable = this.currentItem.querySelector("input[type=checkbox]")
      const isDisabled = toggleable?.hasAttribute("disabled")

      if (toggleable && !isDisabled) {
        toggleable.checked = !toggleable.checked
        toggleable.dispatchEvent(new Event('change', { bubbles: true }))
        event.preventDefault()
      }
    }
  }

  get #visibleItems() {
    return this.itemTargets.filter(item => {
      return item.checkVisibility && item.checkVisibility() && !item.hidden
    })
  }

  // Public accessors
  get visibleItems() {
    return this.#visibleItems
  }

  clearSelection() {
    this.#clearSelection()
    this.currentItem = null
  }

  get hasFocus() {
    return this.element.contains(document.activeElement)
  }

  #keyHandlers = {
    ArrowDown(event) {
      if (this.supportsVerticalNavigationValue) {
        const selectMethod = this.reverseNavigationValue ? this.#selectPrevious.bind(this) : this.#selectNext.bind(this)
        this.#handleArrowKey(event, selectMethod)
      }
    },
    ArrowUp(event) {
      if (this.supportsVerticalNavigationValue) {
        const selectMethod = this.reverseNavigationValue ? this.#selectNext.bind(this) : this.#selectPrevious.bind(this)
        this.#handleArrowKey(event, selectMethod)
      }
    },
    ArrowRight(event) {
      if (this.supportsHorizontalNavigationValue) {
        this.#handleArrowKey(event, this.#selectNext.bind(this))
      }
    },
    ArrowLeft(event) {
      if (this.supportsHorizontalNavigationValue) {
        this.#handleArrowKey(event, this.#selectPrevious.bind(this))
      }
    },
    Enter(event) {
      if (event.isComposing) { return }

      if (event.shiftKey) {
        this.#toggleCurrentItem(event)
      } else {
        this.#clickCurrentItem(event)
      }
    },
    " "(event) {
      // Spacebar toggles checkbox selection
      this.#toggleCurrentItem(event)
    }
  }
}
