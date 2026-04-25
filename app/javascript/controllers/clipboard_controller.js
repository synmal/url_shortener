import { Controller } from "@hotwired/stimulus"

// Copies the value of a sibling input (data-clipboard-target="source") to the clipboard
// and swaps the button icon to a checkmark for visual feedback.
export default class extends Controller {
  static targets = ["source"]

  copy() {
    const input = this.sourceTarget
    navigator.clipboard.writeText(input.value).then(() => {
      const icon = this.element.querySelector("i")
      const original = icon.className
      icon.className = "bi bi-clipboard-check text-success"
      setTimeout(() => { icon.className = original }, 1500)
    }).catch((err) => {
      console.error("[Clipboard] Failed to copy:", err)
      input.select()
      try {
        if (!document.execCommand("copy")) {
          const icon = this.element.querySelector("i")
          const original = icon.className
          icon.className = "bi bi-clipboard-x text-danger"
          setTimeout(() => { icon.className = original }, 1500)
        }
      } catch (fallbackErr) {
        console.error("[Clipboard] Fallback copy also failed:", fallbackErr)
        const icon = this.element.querySelector("i")
        const original = icon.className
        icon.className = "bi bi-clipboard-x text-danger"
        setTimeout(() => { icon.className = original }, 1500)
      }
    })
  }
}
