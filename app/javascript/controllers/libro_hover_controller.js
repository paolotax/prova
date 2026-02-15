import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["libro", "badge"]

  libroTargetConnected(el) {
    el.addEventListener("mouseenter", this._highlightFromLibro)
    el.addEventListener("mouseleave", this._reset)
  }

  libroTargetDisconnected(el) {
    el.removeEventListener("mouseenter", this._highlightFromLibro)
    el.removeEventListener("mouseleave", this._reset)
  }

  badgeTargetConnected(el) {
    el.addEventListener("mouseenter", this._highlightFromBadge)
    el.addEventListener("mouseleave", this._reset)
  }

  badgeTargetDisconnected(el) {
    el.removeEventListener("mouseenter", this._highlightFromBadge)
    el.removeEventListener("mouseleave", this._reset)
  }

  _highlightFromLibro = (e) => {
    const ids = (e.currentTarget.dataset.classeIds || "").split(",")
    this.badgeTargets.forEach(badge => {
      badge.classList.add(ids.includes(badge.dataset.classeId) ? "libro-hover--active" : "libro-hover--dim")
    })
    this.libroTargets.forEach(libro => {
      if (libro !== e.currentTarget) libro.classList.add("libro-hover--dim")
    })
  }

  _highlightFromBadge = (e) => {
    const classeId = e.currentTarget.dataset.classeId
    this.libroTargets.forEach(libro => {
      const ids = (libro.dataset.classeIds || "").split(",")
      libro.classList.add(ids.includes(classeId) ? "libro-hover--active" : "libro-hover--dim")
    })
    this.badgeTargets.forEach(badge => {
      if (badge !== e.currentTarget) badge.classList.add("libro-hover--dim")
    })
  }

  _reset = () => {
    this.libroTargets.forEach(el => el.classList.remove("libro-hover--active", "libro-hover--dim"))
    this.badgeTargets.forEach(el => el.classList.remove("libro-hover--active", "libro-hover--dim"))
  }
}
