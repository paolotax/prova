import t from"@cropper/element";import{ACTION_NONE as e,on as n,EVENT_POINTER_DOWN as i,EVENT_POINTER_MOVE as s,EVENT_POINTER_UP as a,EVENT_WHEEL as o,off as r,isNumber as h,ACTION_TRANSFORM as c,isElement as l,ATTRIBUTE_ACTION as d,EVENT_ACTION_START as f,EVENT_ACTION_MOVE as p,ACTION_ROTATE as u,ACTION_SCALE as $,EVENT_ACTION as g,EVENT_ACTION_END as b,isString as m,isPlainObject as w,isPositiveNumber as P,getAdjustedSizes as v,CROPPER_IMAGE as M,isFunction as Y,CROPPER_CANVAS as X}from"@cropper/utils";var C=':host{display:block;min-height:100px;min-width:200px;overflow:hidden;position:relative;touch-action:none;-webkit-user-select:none;-moz-user-select:none;user-select:none}:host([background]){background-color:#fff;background-image:repeating-linear-gradient(45deg,#ccc 25%,transparent 0,transparent 75%,#ccc 0,#ccc),repeating-linear-gradient(45deg,#ccc 25%,transparent 0,transparent 75%,#ccc 0,#ccc);background-image:repeating-conic-gradient(#ccc 0 25%,#fff 0 50%);background-position:0 0,.5rem .5rem;background-size:1rem 1rem}:host([disabled]){pointer-events:none}:host([disabled]):after{bottom:0;content:"";cursor:not-allowed;display:block;left:0;pointer-events:none;position:absolute;right:0;top:0}';class CropperCanvas extends t{constructor(){super(...arguments);this.$onPointerDown=null;this.$onPointerMove=null;this.$onPointerUp=null;this.$onWheel=null;this.$wheeling=false;this.$pointers=new Map;this.$style=C;this.$action=e;this.background=false;this.disabled=false;this.scaleStep=.1;this.themeColor="#39f"}static get observedAttributes(){return super.observedAttributes.concat(["background","disabled","scale-step"])}connectedCallback(){super.connectedCallback();this.disabled||this.$bind()}disconnectedCallback(){this.disabled||this.$unbind();super.disconnectedCallback()}$propertyChangedCallback(t,e,n){if(!Object.is(n,e)){super.$propertyChangedCallback(t,e,n);switch(t){case"disabled":n?this.$unbind():this.$bind();break}}}$bind(){if(!this.$onPointerDown){this.$onPointerDown=this.$handlePointerDown.bind(this);n(this,i,this.$onPointerDown)}if(!this.$onPointerMove){this.$onPointerMove=this.$handlePointerMove.bind(this);n(this.ownerDocument,s,this.$onPointerMove)}if(!this.$onPointerUp){this.$onPointerUp=this.$handlePointerUp.bind(this);n(this.ownerDocument,a,this.$onPointerUp)}if(!this.$onWheel){this.$onWheel=this.$handleWheel.bind(this);n(this,o,this.$onWheel,{passive:false,capture:true})}}$unbind(){if(this.$onPointerDown){r(this,i,this.$onPointerDown);this.$onPointerDown=null}if(this.$onPointerMove){r(this.ownerDocument,s,this.$onPointerMove);this.$onPointerMove=null}if(this.$onPointerUp){r(this.ownerDocument,a,this.$onPointerUp);this.$onPointerUp=null}if(this.$onWheel){r(this,o,this.$onWheel,{capture:true});this.$onWheel=null}}$handlePointerDown(t){const{buttons:e,button:n,type:i}=t;if(this.disabled||("pointerdown"===i&&"mouse"===t.pointerType||"mousedown"===i)&&(h(e)&&1!==e||h(n)&&0!==n||t.ctrlKey))return;const{$pointers:s}=this;let a="";if(t.changedTouches)Array.from(t.changedTouches).forEach((({identifier:t,pageX:e,pageY:n})=>{s.set(t,{startX:e,startY:n,endX:e,endY:n})}));else{const{pointerId:e=0,pageX:n,pageY:i}=t;s.set(e,{startX:n,startY:i,endX:n,endY:i})}s.size>1?a=c:l(t.target)&&(a=t.target.action||t.target.getAttribute(d)||"");if(false!==this.$emit(f,{action:a,relatedEvent:t})){t.preventDefault();this.$action=a;this.style.willChange="transform"}}$handlePointerMove(t){const{$action:n,$pointers:i}=this;if(this.disabled||n===e||0===i.size)return;if(false===this.$emit(p,{action:n,relatedEvent:t}))return;t.preventDefault();if(t.changedTouches)Array.from(t.changedTouches).forEach((({identifier:t,pageX:e,pageY:n})=>{const s=i.get(t);s&&Object.assign(s,{endX:e,endY:n})}));else{const{pointerId:e=0,pageX:n,pageY:s}=t;const a=i.get(e);a&&Object.assign(a,{endX:n,endY:s})}const s={action:n,relatedEvent:t};if(n===c){const n=new Map(i);let a=0;let o=0;let r=0;let h=0;let c=t.pageX;let l=t.pageY;i.forEach(((t,e)=>{n.delete(e);n.forEach((e=>{let n=e.startX-t.startX;let i=e.startY-t.startY;let s=e.endX-t.endX;let d=e.endY-t.endY;let f=0;let p=0;let u=0;let $=0;0===n?i<0?u=2*Math.PI:i>0&&(u=Math.PI):n>0?u=Math.PI/2+Math.atan(i/n):n<0&&(u=1.5*Math.PI+Math.atan(i/n));0===s?d<0?$=2*Math.PI:d>0&&($=Math.PI):s>0?$=Math.PI/2+Math.atan(d/s):s<0&&($=1.5*Math.PI+Math.atan(d/s));if($>0||u>0){const n=$-u;const i=Math.abs(n);if(i>a){a=i;r=n;c=(t.startX+e.startX)/2;l=(t.startY+e.startY)/2}}n=Math.abs(n);i=Math.abs(i);s=Math.abs(s);d=Math.abs(d);n>0&&i>0?f=Math.sqrt(n*n+i*i):n>0?f=n:i>0&&(f=i);s>0&&d>0?p=Math.sqrt(s*s+d*d):s>0?p=s:d>0&&(p=d);if(f>0&&p>0){const n=(p-f)/f;const i=Math.abs(n);if(i>o){o=i;h=n;c=(t.startX+e.startX)/2;l=(t.startY+e.startY)/2}}}))}));const d=a>0;const f=o>0;if(d&&f){s.rotate=r;s.scale=h;s.centerX=c;s.centerY=l}else if(d){s.action=u;s.rotate=r;s.centerX=c;s.centerY=l}else if(f){s.action=$;s.scale=h;s.centerX=c;s.centerY=l}else s.action=e}else{const[t]=Array.from(i.values());Object.assign(s,t)}i.forEach((t=>{t.startX=t.endX;t.startY=t.endY}));s.action!==e&&this.$emit(g,s,{cancelable:false})}$handlePointerUp(t){const{$action:n,$pointers:i}=this;if(!this.disabled&&n!==e&&false!==this.$emit(b,{action:n,relatedEvent:t})){t.preventDefault();if(t.changedTouches)Array.from(t.changedTouches).forEach((({identifier:t})=>{i.delete(t)}));else{const{pointerId:e=0}=t;i.delete(e)}if(0===i.size){this.style.willChange="";this.$action=e}}}$handleWheel(t){if(this.disabled)return;t.preventDefault();if(this.$wheeling)return;this.$wheeling=true;setTimeout((()=>{this.$wheeling=false}),50);const e=t.deltaY>0?-1:1;const n=e*this.scaleStep;this.$emit(g,{action:$,scale:n,relatedEvent:t},{cancelable:false})}
/**
     * Changes the current action to a new one.
     * @param {string} action The new action.
     * @returns {CropperCanvas} Returns `this` for chaining.
     */$setAction(t){m(t)&&(this.$action=t);return this}
/**
     * Generates a real canvas element, with the image draw into if there is one.
     * @param {object} [options] The available options.
     * @param {number} [options.width] The width of the canvas.
     * @param {number} [options.height] The height of the canvas.
     * @param {Function} [options.beforeDraw] The function called before drawing the image onto the canvas.
     * @returns {Promise} Returns a promise that resolves to the generated canvas element.
     */$toCanvas(t){return new Promise(((e,n)=>{if(!this.isConnected){n(new Error("The current element is not connected to the DOM."));return}const i=document.createElement("canvas");let s=this.offsetWidth;let a=this.offsetHeight;let o=1;if(w(t)&&(P(t.width)||P(t.height))){({width:s,height:a}=v({aspectRatio:s/a,width:t.width,height:t.height}));o=s/this.offsetWidth}i.width=s;i.height=a;const r=this.querySelector(this.$getTagNameOf(M));r?r.$ready().then((n=>{const h=i.getContext("2d");if(h){const[e,c,l,d,f,p]=r.$getTransform();let u=f;let $=p;let g=n.naturalWidth;let b=n.naturalHeight;if(1!==o){u*=o;$*=o;g*=o;b*=o}const m=g/2;const P=b/2;h.fillStyle="transparent";h.fillRect(0,0,s,a);w(t)&&Y(t.beforeDraw)&&t.beforeDraw.call(this,h,i);h.save();h.translate(m,P);h.transform(e,c,l,d,u,$);h.translate(-m,-P);h.drawImage(n,0,0,g,b);h.restore()}e(i)})).catch(n):e(i)}))}}CropperCanvas.$name=X;CropperCanvas.$version="2.0.0-beta.4";export{CropperCanvas as default};
