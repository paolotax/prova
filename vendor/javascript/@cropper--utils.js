const t="undefined"!==typeof window&&"undefined"!==typeof window.document;const n=t?window:{};const e=!!t&&"ontouchstart"in n.document.documentElement;const o=!!t&&"PointerEvent"in n;const s="cropper";const c=`${s}-canvas`;const i=`${s}-crosshair`;const r=`${s}-grid`;const u=`${s}-handle`;const a=`${s}-image`;const f=`${s}-selection`;const l=`${s}-shade`;const d=`${s}-viewer`;const m="select";const p="move";const g="scale";const b="rotate";const h="transform";const w="none";const v="n-resize";const y="e-resize";const O="s-resize";const j="w-resize";const z="ne-resize";const P="nw-resize";const N="se-resize";const C="sw-resize";const E="action";const $=e?"touchend touchcancel":"mouseup";const A=e?"touchmove":"mousemove";const I=e?"touchstart":"mousedown";const M=o?"pointerdown":I;const S=o?"pointermove":A;const L=o?"pointerup pointercancel":$;const R="error";const T="keydown";const k="load";const x="resize";const F="wheel";const U="action";const K="actionend";const B="actionmove";const D="actionstart";const X="change";const Y="transform";
/**
 * Check if the given value is a string.
 * @param {*} value The value to check.
 * @returns {boolean} Returns `true` if the given value is a string, else `false`.
 */function isString(t){return"string"===typeof t}const Z=Number.isNaN||n.isNaN;
/**
 * Check if the given value is a number.
 * @param {*} value The value to check.
 * @returns {boolean} Returns `true` if the given value is a number, else `false`.
 */function isNumber(t){return"number"===typeof t&&!Z(t)}
/**
 * Check if the given value is a positive number.
 * @param {*} value The value to check.
 * @returns {boolean} Returns `true` if the given value is a positive number, else `false`.
 */function isPositiveNumber(t){return isNumber(t)&&t>0&&t<Infinity}
/**
 * Check if the given value is undefined.
 * @param {*} value The value to check.
 * @returns {boolean} Returns `true` if the given value is undefined, else `false`.
 */function isUndefined(t){return"undefined"===typeof t}
/**
 * Check if the given value is an object.
 * @param {*} value - The value to check.
 * @returns {boolean} Returns `true` if the given value is an object, else `false`.
 */function isObject(t){return"object"===typeof t&&null!==t}const{hasOwnProperty:q}=Object.prototype;
/**
 * Check if the given value is a plain object.
 * @param {*} value - The value to check.
 * @returns {boolean} Returns `true` if the given value is a plain object, else `false`.
 */function isPlainObject(t){if(!isObject(t))return false;try{const{constructor:n}=t;const{prototype:e}=n;return n&&e&&q.call(e,"isPrototypeOf")}catch(t){return false}}
/**
 * Check if the given value is a function.
 * @param {*} value The value to check.
 * @returns {boolean} Returns `true` if the given value is a function, else `false`.
 */function isFunction(t){return"function"===typeof t}
/**
 * Check if the given node is an element.
 * @param {*} node The node to check.
 * @returns {boolean} Returns `true` if the given node is an element; otherwise, `false`.
 */function isElement(t){return"object"===typeof t&&null!==t&&1===t.nodeType}const G=/([a-z\d])([A-Z])/g;
/**
 * Transform the given string from camelCase to kebab-case.
 * @param {string} value The value to transform.
 * @returns {string} Returns the transformed value.
 */function toKebabCase(t){return String(t).replace(G,"$1-$2").toLowerCase()}const H=/-[A-z\d]/g;
/**
 * Transform the given string from kebab-case to camelCase.
 * @param {string} value The value to transform.
 * @returns {string} Returns the transformed value.
 */function toCamelCase(t){return t.replace(H,(t=>t.slice(1).toUpperCase()))}const J=/\s\s*/;
/**
 * Remove event listener from the event target.
 * {@link https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/removeEventListener}
 * @param {EventTarget} target The target of the event.
 * @param {string} types The types of the event.
 * @param {EventListenerOrEventListenerObject} listener The listener of the event.
 * @param {EventListenerOptions} [options] The options specify characteristics about the event listener.
 */function off(t,n,e,o){n.trim().split(J).forEach((n=>{t.removeEventListener(n,e,o)}))}
/**
 * Add event listener to the event target.
 * {@link https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/addEventListener}
 * @param {EventTarget} target The target of the event.
 * @param {string} types The types of the event.
 * @param {EventListenerOrEventListenerObject} listener The listener of the event.
 * @param {AddEventListenerOptions} [options] The options specify characteristics about the event listener.
 */function on(t,n,e,o){n.trim().split(J).forEach((n=>{t.addEventListener(n,e,o)}))}
/**
 * Add once event listener to the event target.
 * @param {EventTarget} target The target of the event.
 * @param {string} types The types of the event.
 * @param {EventListenerOrEventListenerObject} listener The listener of the event.
 * @param {AddEventListenerOptions} [options] The options specify characteristics about the event listener.
 */function once(t,n,e,o){on(t,n,e,Object.assign(Object.assign({},o),{once:true}))}const Q={bubbles:true,cancelable:true,composed:true};
/**
 * Dispatch event on the event target.
 * {@link https://developer.mozilla.org/en-US/docs/Web/API/EventTarget/dispatchEvent}
 * @param {EventTarget} target The target of the event.
 * @param {string} type The name of the event.
 * @param {*} [detail] The data passed when initializing the event.
 * @param {CustomEventInit} [options] The other event options.
 * @returns {boolean} Returns the result value.
 */function emit(t,n,e,o){return t.dispatchEvent(new CustomEvent(n,Object.assign(Object.assign(Object.assign({},Q),{detail:e}),o)))}const V=Promise.resolve();
/**
 * Defers the callback to be executed after the next DOM update cycle.
 * @param {*} [context] The `this` context.
 * @param {Function} [callback] The callback to execute after the next DOM update cycle.
 * @returns {Promise} A promise that resolves to nothing.
 */function nextTick(t,n){return n?V.then(t?n.bind(t):n):V}
/**
 * Get the offset base on the document.
 * @param {Element} element The target element.
 * @returns {object} The offset data.
 */function getOffset(t){const{documentElement:e}=t.ownerDocument;const o=t.getBoundingClientRect();return{left:o.left+(n.pageXOffset-e.clientLeft),top:o.top+(n.pageYOffset-e.clientTop)}}const W=/deg|g?rad|turn$/i;
/**
 * Convert an angle to a radian number.
 * {@link https://developer.mozilla.org/en-US/docs/Web/CSS/angle}
 * @param {number|string} angle The angle to convert.
 * @returns {number} Returns the radian number.
 */function toAngleInRadian(t){const n=parseFloat(t)||0;if(0!==n){const[e="rad"]=String(t).match(W)||[];switch(e.toLowerCase()){case"deg":return n/360*(2*Math.PI);case"grad":return n/400*(2*Math.PI);case"turn":return n*(2*Math.PI)}}return n}const _="contain";const tt="cover";
/**
 * Get the max sizes in a rectangle under the given aspect ratio.
 * @param {object} data The original sizes.
 * @param {string} [type] The adjust type.
 * @returns {object} Returns the result sizes.
 */function getAdjustedSizes(t,n=_){const{aspectRatio:e}=t;let{width:o,height:s}=t;const c=isPositiveNumber(o);const i=isPositiveNumber(s);if(c&&i){const t=s*e;n===_&&t>o||n===tt&&t<o?s=o/e:o=s*e}else c?s=o/e:i&&(o=s*e);return{width:o,height:s}}
/**
 * Multiply multiple matrices.
 * @param {Array} matrix The first matrix.
 * @param {Array} args The rest matrices.
 * @returns {Array} Returns the result matrix.
 */function multiplyMatrices(t,...n){if(0===n.length)return t;const[e,o,s,c,i,r]=t;const[u,a,f,l,d,m]=n[0];t=[e*u+s*a,o*u+c*a,e*f+s*l,o*f+c*l,e*d+s*m+i,o*d+c*m+r];return multiplyMatrices(t,...n.slice(1))}export{p as ACTION_MOVE,w as ACTION_NONE,y as ACTION_RESIZE_EAST,v as ACTION_RESIZE_NORTH,z as ACTION_RESIZE_NORTHEAST,P as ACTION_RESIZE_NORTHWEST,O as ACTION_RESIZE_SOUTH,N as ACTION_RESIZE_SOUTHEAST,C as ACTION_RESIZE_SOUTHWEST,j as ACTION_RESIZE_WEST,b as ACTION_ROTATE,g as ACTION_SCALE,m as ACTION_SELECT,h as ACTION_TRANSFORM,E as ATTRIBUTE_ACTION,c as CROPPER_CANVAS,i as CROPPER_CROSSHAIR,r as CROPPER_GIRD,u as CROPPER_HANDLE,a as CROPPER_IMAGE,f as CROPPER_SELECTION,l as CROPPER_SHADE,d as CROPPER_VIEWER,U as EVENT_ACTION,K as EVENT_ACTION_END,B as EVENT_ACTION_MOVE,D as EVENT_ACTION_START,X as EVENT_CHANGE,R as EVENT_ERROR,T as EVENT_KEYDOWN,k as EVENT_LOAD,M as EVENT_POINTER_DOWN,S as EVENT_POINTER_MOVE,L as EVENT_POINTER_UP,x as EVENT_RESIZE,$ as EVENT_TOUCH_END,A as EVENT_TOUCH_MOVE,I as EVENT_TOUCH_START,Y as EVENT_TRANSFORM,F as EVENT_WHEEL,o as HAS_POINTER_EVENT,t as IS_BROWSER,e as IS_TOUCH_DEVICE,s as NAMESPACE,n as WINDOW,emit,getAdjustedSizes,getOffset,isElement,isFunction,Z as isNaN,isNumber,isObject,isPlainObject,isPositiveNumber,isString,isUndefined,multiplyMatrices,nextTick,off,on,once,toAngleInRadian,toCamelCase,toKebabCase};

