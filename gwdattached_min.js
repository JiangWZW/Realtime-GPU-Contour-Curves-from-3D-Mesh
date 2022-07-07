(function(){/*

 Copyright The Closure Library Authors.
 SPDX-License-Identifier: Apache-2.0
*/
'use strict';var b="function"==typeof Object.create?Object.create:function(a){function c(){}c.prototype=a;return new c},d;if("function"==typeof Object.setPrototypeOf)d=Object.setPrototypeOf;else{var e;a:{var f={a:!0},g={};try{g.__proto__=f;e=g.a;break a}catch(a){}e=!1}d=e?function(a,c){a.__proto__=c;if(a.__proto__!==c)throw new TypeError(a+" is not extensible");return a}:null}var k=d;function l(a,c){var h=void 0===h?null:h;var n=document.createEvent("CustomEvent");n.initCustomEvent(a,!0,!0,h);c.dispatchEvent(n)};function m(){return HTMLElement.call(this)||this}var p=HTMLElement;m.prototype=b(p.prototype);m.prototype.constructor=m;if(k)k(m,p);else for(var q in p)if("prototype"!=q)if(Object.defineProperties){var r=Object.getOwnPropertyDescriptor(p,q);r&&Object.defineProperty(m,q,r)}else m[q]=p[q];m.prototype.connectedCallback=function(){l("attached",this)};m.prototype.disconnectedCallback=function(){l("detached",this)};customElements.define("gwd-attached",m);}).call(this);
