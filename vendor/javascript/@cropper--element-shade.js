import t from"@cropper/element";import{CROPPER_CANVAS as i,CROPPER_SELECTION as s,ACTION_SELECT as n,on as e,EVENT_ACTION_START as h,EVENT_ACTION_END as a,EVENT_CHANGE as o,off as r,isNumber as d,WINDOW as c,CROPPER_SHADE as l}from"@cropper/utils";var $=":host{display:block;height:0;left:0;outline:var(--theme-color) solid 1px;position:relative;top:0;width:0}:host([transparent]){outline-color:transparent}";const C=new WeakMap;class CropperShade extends t{constructor(){super(...arguments);this.$onCanvasChange=null;this.$onCanvasActionEnd=null;this.$onCanvasActionStart=null;this.$style=$;this.x=0;this.y=0;this.width=0;this.height=0;this.slottable=false;this.themeColor="rgba(0, 0, 0, 0.65)"}set $canvas(t){C.set(this,t)}get $canvas(){return C.get(this)}static get observedAttributes(){return super.observedAttributes.concat(["height","width","x","y"])}connectedCallback(){super.connectedCallback();const t=this.closest(this.$getTagNameOf(i));if(t){this.$canvas=t;this.style.position="absolute";const i=t.querySelector(this.$getTagNameOf(s));if(i){this.$onCanvasActionStart=t=>{i.hidden&&t.detail.action===n&&(this.hidden=false)};this.$onCanvasActionEnd=t=>{i.hidden&&t.detail.action===n&&(this.hidden=true)};this.$onCanvasChange=t=>{const{x:s,y:n,width:e,height:h}=t.detail;this.$change(s,n,e,h);(i.hidden||0===s&&0===n&&0===e&&0===h)&&(this.hidden=true)};e(t,h,this.$onCanvasActionStart);e(t,a,this.$onCanvasActionEnd);e(t,o,this.$onCanvasChange)}}this.$render()}disconnectedCallback(){const{$canvas:t}=this;if(t){if(this.$onCanvasActionStart){r(t,h,this.$onCanvasActionStart);this.$onCanvasActionStart=null}if(this.$onCanvasActionEnd){r(t,a,this.$onCanvasActionEnd);this.$onCanvasActionEnd=null}if(this.$onCanvasChange){r(t,o,this.$onCanvasChange);this.$onCanvasChange=null}}super.disconnectedCallback()}
/**
     * Changes the position and/or size of the shade.
     * @param {number} x The new position in the horizontal direction.
     * @param {number} y The new position in the vertical direction.
     * @param {number} [width] The new width.
     * @param {number} [height] The new height.
     * @returns {CropperShade} Returns `this` for chaining.
     */$change(t,i,s=this.width,n=this.height){if(!d(t)||!d(i)||!d(s)||!d(n)||t===this.x&&i===this.y&&s===this.width&&n===this.height)return this;this.hidden&&(this.hidden=false);this.x=t;this.y=i;this.width=s;this.height=n;return this.$render()}
/**
     * Resets the shade to its initial position and size.
     * @returns {CropperShade} Returns `this` for chaining.
     */$reset(){return this.$change(0,0,0,0)}
/**
     * Refreshes the position or size of the shade.
     * @returns {CropperShade} Returns `this` for chaining.
     */$render(){return this.$setStyles({transform:`translate(${this.x}px, ${this.y}px)`,width:this.width,height:this.height,outlineWidth:c.innerWidth})}}CropperShade.$name=l;CropperShade.$version="2.0.0-beta.4";export{CropperShade as default};

