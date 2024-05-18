import CheckboxSelectAll from 'stimulus-checkbox-select-all'

// Connects to data-controller="tax-checkbox-select-all"
export default class extends CheckboxSelectAll {

  static targets = ['formMulti', 'label']

  connect() {
    super.connect()
  }

  toggle(e) {
    super.toggle(e)
    this.toggleTax()
  }

  refresh() {
    super.refresh()
    this.toggleTax()
  }

  toggleTax() {

    if (this.checked.length === 0) {
      this.labelTarget.innerHTML = 'seleziona';
    } else if ( this.checked.length === 1 ) {
      this.labelTarget.innerHTML = '1 selezionata';
    } else {
      this.labelTarget.innerHTML = this.checked.length + ' selezionate';
    }

    if (this.checked.length > 0) {
      this.formMultiTarget.style.display = "block";
    } else {
      this.formMultiTarget.style.display = "none";
    }
  }
}
