import t from"@cropper/element";import{CROPPER_CANVAS as s,on as i,EVENT_ACTION_START as n,EVENT_ACTION_END as a,EVENT_ACTION as e,EVENT_LOAD as o,off as r,ACTION_TRANSFORM as h,ACTION_ROTATE as c,ACTION_SCALE as l,ACTION_NONE as $,ACTION_MOVE as d,CROPPER_SELECTION as m,EVENT_ERROR as u,once as b,isFunction as g,isNumber as f,toAngleInRadian as v,multiplyMatrices as C,EVENT_TRANSFORM as p,CROPPER_IMAGE as A}from"@cropper/utils";var x=":host{display:inline-block}img{display:block;height:100%;max-height:none!important;max-width:none!important;min-height:0!important;min-width:0!important;width:100%}";const w=new WeakMap;const k=["alt","crossorigin","decoding","importance","loading","referrerpolicy","sizes","src","srcset"];class CropperImage extends t{constructor(){super(...arguments);this.$matrix=[1,0,0,1,0,0];this.$onLoad=null;this.$onCanvasAction=null;this.$onCanvasActionEnd=null;this.$onCanvasActionStart=null;this.$actionStartTarget=null;this.$style=x;this.$image=new Image;this.rotatable=true;this.scalable=true;this.skewable=true;this.slottable=false;this.translatable=true}set $canvas(t){w.set(this,t)}get $canvas(){return w.get(this)}static get observedAttributes(){return super.observedAttributes.concat(k,["rotatable","scalable","skewable","translatable"])}attributeChangedCallback(t,s,i){if(!Object.is(i,s)){super.attributeChangedCallback(t,s,i);k.includes(t)&&this.$image.setAttribute(t,i)}}connectedCallback(){super.connectedCallback();const{$image:t}=this;const r=this.closest(this.$getTagNameOf(s));if(r){this.$canvas=r;this.$setStyles({display:"block",position:"absolute"});this.$onCanvasActionStart=t=>{var s,i;this.$actionStartTarget=null===(i=null===(s=t.detail)||void 0===s?void 0:s.relatedEvent)||void 0===i?void 0:i.target};this.$onCanvasActionEnd=()=>{this.$actionStartTarget=null};this.$onCanvasAction=this.$handleAction.bind(this);i(r,n,this.$onCanvasActionStart);i(r,a,this.$onCanvasActionEnd);i(r,e,this.$onCanvasAction)}this.$onLoad=this.$handleLoad.bind(this);i(t,o,this.$onLoad);this.$getShadowRoot().appendChild(t)}disconnectedCallback(){const{$image:t,$canvas:s}=this;if(s){if(this.$onCanvasActionStart){r(s,n,this.$onCanvasActionStart);this.$onCanvasActionStart=null}if(this.$onCanvasActionEnd){r(s,a,this.$onCanvasActionEnd);this.$onCanvasActionEnd=null}if(this.$onCanvasAction){r(s,e,this.$onCanvasAction);this.$onCanvasAction=null}}if(t&&this.$onLoad){r(t,o,this.$onLoad);this.$onLoad=null}this.$getShadowRoot().removeChild(t);super.disconnectedCallback()}$handleLoad(){const{$image:t}=this;this.$setStyles({width:t.naturalWidth,height:t.naturalHeight});this.$canvas&&this.$center("cover")}$handleAction(t){if(this.hidden||!(this.rotatable||this.scalable||this.translatable))return;const{$canvas:s}=this;const{detail:i}=t;if(i){const{relatedEvent:t}=i;let{action:n}=i;n!==h||this.rotatable&&this.scalable||(n=this.rotatable?c:this.scalable?l:$);switch(n){case d:if(this.translatable){const t=this.$getTagNameOf(m);let n=s.querySelector(t);n&&n.multiple&&!n.active&&(n=s.querySelector(`${t}[active]`));n&&!n.hidden&&n.movable&&this.$actionStartTarget&&n.contains(this.$actionStartTarget)||this.$move(i.endX-i.startX,i.endY-i.startY)}break;case c:if(this.rotatable)if(t){const{x:s,y:n}=this.getBoundingClientRect();this.$rotate(i.rotate,t.clientX-s,t.clientY-n)}else this.$rotate(i.rotate);break;case l:if(this.scalable)if(t){const{x:s,y:n}=this.getBoundingClientRect();this.$zoom(i.scale,t.clientX-s,t.clientY-n)}else this.$zoom(i.scale);break;case h:if(this.rotatable&&this.scalable){const{rotate:s}=i;let{scale:n}=i;n<0?n=1/(1-n):n+=1;const a=Math.cos(s);const e=Math.sin(s);const[o,r,h,c]=[a*n,e*n,-e*n,a*n];if(t){const s=this.getBoundingClientRect();const i=t.clientX-s.x;const n=t.clientY-s.y;const[a,e,l,$]=this.$matrix;const d=s.width/2;const m=s.height/2;const u=i-d;const b=n-m;const g=(u*$-l*b)/(a*$-l*e);const f=(b-e*g)/$;this.$transform(o,r,h,c,g*(1-o)+f*h,f*(1-c)+g*r)}else this.$transform(o,r,h,c,0,0)}break}}}
/**
     * Defers the callback to execute after successfully loading the image.
     * @param {Function} [callback] The callback to execute after successfully loading the image.
     * @returns {Promise} Returns a promise that resolves to the image element.
     */$ready(t){const{$image:s}=this;const i=new Promise(((t,i)=>{const n=new Error("Failed to load the image source");if(s.complete)s.naturalWidth>0&&s.naturalHeight>0?t(s):i(n);else{const onLoad=()=>{r(s,u,onError);t(s)};const onError=()=>{r(s,o,onLoad);i(n)};b(s,o,onLoad);b(s,u,onError)}}));g(t)&&i.then((s=>{t(s);return s}));return i}
/**
     * Aligns the image to the center of its parent element.
     * @param {string} [size] The size of the image.
     * @returns {CropperImage} Returns `this` for chaining.
     */$center(t){const{parentElement:s}=this;if(!s)return this;const i=s.getBoundingClientRect();const n=i.width;const a=i.height;const{x:e,y:o,width:r,height:h}=this.getBoundingClientRect();const c=e+r/2;const l=o+h/2;const $=i.x+n/2;const d=i.y+a/2;this.$move($-c,d-l);if(t&&(r!==n||h!==a)){const s=n/r;const i=a/h;switch(t){case"cover":this.$scale(Math.max(s,i));break;case"contain":this.$scale(Math.min(s,i));break}}return this}
/**
     * Moves the image.
     * @param {number} x The moving distance in the horizontal direction.
     * @param {number} [y] The moving distance in the vertical direction.
     * @returns {CropperImage} Returns `this` for chaining.
     */$move(t,s=t){if(this.translatable&&f(t)&&f(s)){const[i,n,a,e]=this.$matrix;const o=(t*e-a*s)/(i*e-a*n);const r=(s-n*o)/e;this.$translate(o,r)}return this}
/**
     * Moves the image to a specific position.
     * @param {number} x The new position in the horizontal direction.
     * @param {number} [y] The new position in the vertical direction.
     * @returns {CropperImage} Returns `this` for chaining.
     */$moveTo(t,s=t){if(this.translatable&&f(t)&&f(s)){const[i,n,a,e]=this.$matrix;const o=(t*e-a*s)/(i*e-a*n);const r=(s-n*o)/e;this.$setTransform(i,n,a,e,o,r)}return this}
/**
     * Rotates the image.
     * {@link https://developer.mozilla.org/en-US/docs/Web/CSS/transform-function/rotate}
     * {@link https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/rotate}
     * @param {number|string} angle The rotation angle (in radians).
     * @param {number} [x] The rotation origin in the horizontal, defaults to the center of the image.
     * @param {number} [y] The rotation origin in the vertical, defaults to the center of the image.
     * @returns {CropperImage} Returns `this` for chaining.
     */$rotate(t,s,i){if(this.rotatable){const n=v(t);const a=Math.cos(n);const e=Math.sin(n);const[o,r,h,c]=[a,e,-e,a];if(f(s)&&f(i)){const[t,n,a,e]=this.$matrix;const{width:l,height:$}=this.getBoundingClientRect();const d=l/2;const m=$/2;const u=s-d;const b=i-m;const g=(u*e-a*b)/(t*e-a*n);const f=(b-n*g)/e;this.$transform(o,r,h,c,g*(1-o)-f*h,f*(1-c)-g*r)}else this.$transform(o,r,h,c,0,0)}return this}
/**
     * Zooms the image.
     * @param {number} scale The zoom factor. Positive numbers for zooming in, and negative numbers for zooming out.
     * @param {number} [x] The zoom origin in the horizontal, defaults to the center of the image.
     * @param {number} [y] The zoom origin in the vertical, defaults to the center of the image.
     * @returns {CropperImage} Returns `this` for chaining.
     */$zoom(t,s,i){if(!this.scalable||0===t)return this;t<0?t=1/(1-t):t+=1;if(f(s)&&f(i)){const[n,a,e,o]=this.$matrix;const{width:r,height:h}=this.getBoundingClientRect();const c=r/2;const l=h/2;const $=s-c;const d=i-l;const m=($*o-e*d)/(n*o-e*a);const u=(d-a*m)/o;this.$transform(t,0,0,t,m*(1-t),u*(1-t))}else this.$scale(t);return this}
/**
     * Scales the image.
     * {@link https://developer.mozilla.org/en-US/docs/Web/CSS/transform-function/scale}
     * {@link https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/scale}
     * @param {number} x The scaling factor in the horizontal direction.
     * @param {number} [y] The scaling factor in the vertical direction.
     * @returns {CropperImage} Returns `this` for chaining.
     */$scale(t,s=t){this.scalable&&this.$transform(t,0,0,s,0,0);return this}
/**
     * Skews the image.
     * {@link https://developer.mozilla.org/en-US/docs/Web/CSS/transform-function/skew}
     * {@link https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/transform}
     * @param {number|string} x The skewing angle in the horizontal direction.
     * @param {number|string} [y] The skewing angle in the vertical direction.
     * @returns {CropperImage} Returns `this` for chaining.
     */$skew(t,s=0){if(this.skewable){const i=v(t);const n=v(s);this.$transform(1,Math.tan(n),Math.tan(i),1,0,0)}return this}
/**
     * Translates the image.
     * {@link https://developer.mozilla.org/en-US/docs/Web/CSS/transform-function/translate}
     * {@link https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/translate}
     * @param {number} x The translating distance in the horizontal direction.
     * @param {number} [y] The translating distance in the vertical direction.
     * @returns {CropperImage} Returns `this` for chaining.
     */$translate(t,s=t){this.translatable&&f(t)&&f(s)&&this.$transform(1,0,0,1,t,s);return this}
/**
     * Transforms the image.
     * {@link https://developer.mozilla.org/en-US/docs/Web/CSS/transform-function/matrix}
     * {@link https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/transform}
     * @param {number} a The scaling factor in the horizontal direction.
     * @param {number} b The skewing angle in the vertical direction.
     * @param {number} c The skewing angle in the horizontal direction.
     * @param {number} d The scaling factor in the vertical direction.
     * @param {number} e The translating distance in the horizontal direction.
     * @param {number} f The translating distance in the vertical direction.
     * @returns {CropperImage} Returns `this` for chaining.
     */$transform(t,s,i,n,a,e){return f(t)&&f(s)&&f(i)&&f(n)&&f(a)&&f(e)?this.$setTransform(C(this.$matrix,[t,s,i,n,a,e])):this}
/**
     * Resets (overrides) the current transform to the specific identity matrix.
     * {@link https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/setTransform}
     * @param {number|Array} a The scaling factor in the horizontal direction.
     * @param {number} b The skewing angle in the vertical direction.
     * @param {number} c The skewing angle in the horizontal direction.
     * @param {number} d The scaling factor in the vertical direction.
     * @param {number} e The translating distance in the horizontal direction.
     * @param {number} f The translating distance in the vertical direction.
     * @returns {CropperImage} Returns `this` for chaining.
     */$setTransform(t,s,i,n,a,e){if(this.rotatable||this.scalable||this.skewable||this.translatable){Array.isArray(t)&&([t,s,i,n,a,e]=t);if(f(t)&&f(s)&&f(i)&&f(n)&&f(a)&&f(e)){const o=[t,s,i,n,a,e];if(false===this.$emit(p,{matrix:o,oldMatrix:this.$matrix}))return this;this.$matrix=o;this.style.transform=`matrix(${o.join(", ")})`}}return this}
/**
     * Retrieves the current transformation matrix being applied to the element.
     * {@link https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/getTransform}
     * @returns {Array} Returns the readonly transformation matrix.
     */$getTransform(){return this.$matrix.slice()}
/**
     * Resets the current transform to the initial identity matrix.
     * {@link https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/resetTransform}
     * @returns {CropperImage} Returns `this` for chaining.
     */$resetTransform(){return this.$setTransform([1,0,0,1,0,0])}}CropperImage.$name=A;CropperImage.$version="2.0.0-beta.4";export{CropperImage as default};

