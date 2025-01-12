/***
 * Excerpted from "Hotwire Native for Rails Developers",
 * published by The Pragmatic Bookshelf.
 * Copyrights apply to this code. It may not be used to create training material,
 * courses, books, articles, and the like. Contact us if you are in doubt.
 * We make no guarantees that this code is fit for any purpose.
 * Visit https://pragprog.com/titles/jmnative for more book information.
***/
import { BridgeComponent } from "@hotwired/hotwire-native-bridge"

export default class extends BridgeComponent {
  static component = "button"

  connect() {
    super.connect()

    const title = this.bridgeElement.bridgeAttribute("title")
    const imageName = this.bridgeElement.bridgeAttribute("ios-image-name")
    const iconName = this.bridgeElement.bridgeAttribute("android-icon-name")

    this.send("connect", {title, imageName, iconName}, () => {
      this.bridgeElement.click()
    })
  }
}
