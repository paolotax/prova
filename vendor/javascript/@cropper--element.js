import{WINDOW as t,toCamelCase as e,toKebabCase as s,isNaN as o,isUndefined as r,isNumber as i,emit as n,nextTick as a,isObject as h,IS_BROWSER as l}from"@cropper/utils";var c=":host([hidden]){display:none!important}";const d=/left|top|width|height/i;const p="open";const u=new WeakMap;const m=new WeakMap;const b=new Map;const y=t.document&&Array.isArray(t.document.adoptedStyleSheets)&&"replaceSync"in t.CSSStyleSheet.prototype;class CropperElement extends HTMLElement{get $sharedStyle(){return`${this.themeColor?`:host{--theme-color: ${this.themeColor};}`:""}${c}`}constructor(){var t,e;super();this.shadowRootMode=p;this.slottable=true;const s=null===(e=null===(t=Object.getPrototypeOf(this))||void 0===t?void 0:t.constructor)||void 0===e?void 0:e.$name;s&&b.set(s,this.tagName.toLowerCase())}static get observedAttributes(){return["shadow-root-mode","slottable","theme-color"]}attributeChangedCallback(t,s,o){if(Object.is(o,s))return;const r=e(t);const i=this[r];let n=o;switch(typeof i){case"boolean":n=null!==o&&"false"!==o;break;case"number":n=Number(o);break}this[r]=n;switch(t){case"theme-color":{const t=m.get(this);const e=this.$sharedStyle;t&&e&&(y?t.replaceSync(e):t.textContent=e);break}}}$propertyChangedCallback(t,e,r){if(!Object.is(r,e)){t=s(t);switch(typeof r){case"boolean":true===r?this.hasAttribute(t)||this.setAttribute(t,""):this.removeAttribute(t);break;case"number":r=o(r)?"":String(r);default:r?this.getAttribute(t)!==r&&this.setAttribute(t,r):this.removeAttribute(t)}}}connectedCallback(){Object.getPrototypeOf(this).constructor.observedAttributes.forEach((t=>{const s=e(t);let o=this[s];r(o)||this.$propertyChangedCallback(s,void 0,o);Object.defineProperty(this,s,{enumerable:true,configurable:true,get(){return o},set(t){const e=o;o=t;this.$propertyChangedCallback(s,e,t)}})}));const t=this.attachShadow({mode:this.shadowRootMode||p});this.shadowRoot||u.set(this,t);m.set(this,this.$addStyles(this.$sharedStyle));this.$style&&this.$addStyles(this.$style);if(this.$template){const e=document.createElement("template");e.innerHTML=this.$template;t.appendChild(e.content)}if(this.slottable){const e=document.createElement("slot");t.appendChild(e)}}disconnectedCallback(){m.has(this)&&m.delete(this);u.has(this)&&u.delete(this)}$getTagNameOf(t){var e;return null!==(e=b.get(t))&&void 0!==e?e:t}$setStyles(t){Object.keys(t).forEach((e=>{let s=t[e];i(s)&&(s=0!==s&&d.test(e)?`${s}px`:String(s));this.style[e]=s}));return this}
/**
     * Outputs the shadow root of the element.
     * @returns {ShadowRoot} Returns the shadow root.
     */$getShadowRoot(){return this.shadowRoot||u.get(this)}
/**
     * Adds styles to the shadow root.
     * @param {string} styles The styles to add.
     * @returns {CSSStyleSheet|HTMLStyleElement} Returns the generated style sheet.
     */$addStyles(t){let e;const s=this.$getShadowRoot();if(y){e=new CSSStyleSheet;e.replaceSync(t);s.adoptedStyleSheets=s.adoptedStyleSheets.concat(e)}else{e=document.createElement("style");e.textContent=t;s.appendChild(e)}return e}
/**
     * Dispatches an event at the element.
     * @param {string} type The name of the event.
     * @param {*} [detail] The data passed when initializing the event.
     * @param {CustomEventInit} [options] The other event options.
     * @returns {boolean} Returns the result value.
     */$emit(t,e,s){return n(this,t,e,s)}
/**
     * Defers the callback to be executed after the next DOM update cycle.
     * @param {Function} [callback] The callback to execute after the next DOM update cycle.
     * @returns {Promise} A promise that resolves to nothing.
     */$nextTick(t){return a(this,t)}
/**
     * Defines the constructor as a new custom element.
     * {@link https://developer.mozilla.org/en-US/docs/Web/API/CustomElementRegistry/define}
     * @param {string|object} [name] The element name.
     * @param {object} [options] The element definition options.
     */static $define(e,o){if(h(e)){o=e;e=""}e||(e=this.$name||this.name);e=s(e);l&&t.customElements&&!t.customElements.get(e)&&customElements.define(e,this,o)}}CropperElement.$version="2.0.0-beta.4";export{CropperElement as default};

