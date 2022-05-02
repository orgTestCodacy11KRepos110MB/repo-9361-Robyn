"use strict";(self.webpackChunkmmm_for_all=self.webpackChunkmmm_for_all||[]).push([[360],{3905:function(e,t,n){n.d(t,{Zo:function(){return l},kt:function(){return d}});var r=n(7294);function o(e,t,n){return t in e?Object.defineProperty(e,t,{value:n,enumerable:!0,configurable:!0,writable:!0}):e[t]=n,e}function i(e,t){var n=Object.keys(e);if(Object.getOwnPropertySymbols){var r=Object.getOwnPropertySymbols(e);t&&(r=r.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),n.push.apply(n,r)}return n}function a(e){for(var t=1;t<arguments.length;t++){var n=null!=arguments[t]?arguments[t]:{};t%2?i(Object(n),!0).forEach((function(t){o(e,t,n[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(n)):i(Object(n)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(n,t))}))}return e}function u(e,t){if(null==e)return{};var n,r,o=function(e,t){if(null==e)return{};var n,r,o={},i=Object.keys(e);for(r=0;r<i.length;r++)n=i[r],t.indexOf(n)>=0||(o[n]=e[n]);return o}(e,t);if(Object.getOwnPropertySymbols){var i=Object.getOwnPropertySymbols(e);for(r=0;r<i.length;r++)n=i[r],t.indexOf(n)>=0||Object.prototype.propertyIsEnumerable.call(e,n)&&(o[n]=e[n])}return o}var c=r.createContext({}),s=function(e){var t=r.useContext(c),n=t;return e&&(n="function"==typeof e?e(t):a(a({},t),e)),n},l=function(e){var t=s(e.components);return r.createElement(c.Provider,{value:t},e.children)},p={inlineCode:"code",wrapper:function(e){var t=e.children;return r.createElement(r.Fragment,{},t)}},f=r.forwardRef((function(e,t){var n=e.components,o=e.mdxType,i=e.originalType,c=e.parentName,l=u(e,["components","mdxType","originalType","parentName"]),f=s(n),d=o,m=f["".concat(c,".").concat(d)]||f[d]||p[d]||i;return n?r.createElement(m,a(a({ref:t},l),{},{components:n})):r.createElement(m,a({ref:t},l))}));function d(e,t){var n=arguments,o=t&&t.mdxType;if("string"==typeof e||o){var i=n.length,a=new Array(i);a[0]=f;var u={};for(var c in t)hasOwnProperty.call(t,c)&&(u[c]=t[c]);u.originalType=e,u.mdxType="string"==typeof e?e:o,a[1]=u;for(var s=2;s<i;s++)a[s]=n[s];return r.createElement.apply(null,a)}return r.createElement.apply(null,n)}f.displayName="MDXCreateElement"},3919:function(e,t,n){function r(e){return!0===/^(\w*:|\/\/)/.test(e)}function o(e){return void 0!==e&&!r(e)}n.d(t,{b:function(){return r},Z:function(){return o}})},4996:function(e,t,n){n.d(t,{C:function(){return i},Z:function(){return a}});var r=n(2263),o=n(3919);function i(){var e=(0,r.Z)().siteConfig,t=(e=void 0===e?{}:e).baseUrl,n=void 0===t?"/":t,i=e.url;return{withBaseUrl:function(e,t){return function(e,t,n,r){var i=void 0===r?{}:r,a=i.forcePrependBaseUrl,u=void 0!==a&&a,c=i.absolute,s=void 0!==c&&c;if(!n)return n;if(n.startsWith("#"))return n;if((0,o.b)(n))return n;if(u)return t+n;var l=n.startsWith(t)?n:t+n.replace(/^\//,"");return s?e+l:l}(i,n,e,t)}}}function a(e,t){return void 0===t&&(t={}),(0,i().withBaseUrl)(e,t)}},4590:function(e,t,n){n.r(t),n.d(t,{frontMatter:function(){return c},contentTitle:function(){return s},metadata:function(){return l},toc:function(){return p},default:function(){return d}});var r=n(7462),o=n(3366),i=(n(7294),n(3905)),a=n(4996),u=["components"],c={id:"contributing",title:"Getting help and contributing"},s=void 0,l={unversionedId:"contributing",id:"contributing",isDocsHomePage:!1,title:"Getting help and contributing",description:"Our vision is to establish & build a community of MMM methodologists, discussing innovation and contributing to open source code",source:"@site/docs/contributing.mdx",sourceDirName:".",slug:"/contributing",permalink:"/Robyn/docs/contributing",editUrl:"https://github.com/facebookexperimental/Robyn/edit/main/website/docs/contributing.mdx",tags:[],version:"current",frontMatter:{id:"contributing",title:"Getting help and contributing"},sidebar:"someSidebar",previous:{title:"Success Stories using Robyn",permalink:"/Robyn/docs/success-stories"},next:{title:"About Robyn",permalink:"/Robyn/docs/about"}},p=[{value:"R Code Documentation",id:"r-code-documentation",children:[]},{value:"Facebook Group",id:"facebook-group",children:[]},{value:"Github",id:"github",children:[]}],f={toc:p};function d(e){var t=e.components,n=(0,o.Z)(e,u);return(0,i.kt)("wrapper",(0,r.Z)({},f,n,{components:t,mdxType:"MDXLayout"}),(0,i.kt)("p",null,(0,i.kt)("strong",{parentName:"p"},"Our vision is to establish & build a community of MMM methodologists, discussing innovation and contributing to open source code")),(0,i.kt)("h3",{id:"r-code-documentation"},"R Code Documentation"),(0,i.kt)("p",null,"Run ",(0,i.kt)("inlineCode",{parentName:"p"},'help(package = "Robyn")')," to see the documentation for all functions and parameters therein contained in the Robyn package. This will be the most up to date place to see the code documentation"),(0,i.kt)("h3",{id:"facebook-group"},(0,i.kt)("a",{parentName:"h3",href:"https://www.facebook.com/groups/954715125296621"},"Facebook Group")),(0,i.kt)("ul",null,(0,i.kt)("li",{parentName:"ul"},"Primary channel for ",(0,i.kt)("strong",{parentName:"li"},"discussions")),(0,i.kt)("li",{parentName:"ul"},"Interaction with us & other community members"),(0,i.kt)("li",{parentName:"ul"},"Our communication channel to you"),(0,i.kt)("li",{parentName:"ul"},"Place to get peer-to-peer help"),(0,i.kt)("li",{parentName:"ul"},"Raise our awareness to your project / application / use case")),(0,i.kt)("img",{alt:"robyn group",src:(0,a.Z)("/img/facebook-group.png")}),(0,i.kt)("h3",{id:"github"},(0,i.kt)("a",{parentName:"h3",href:"https://github.com/facebookexperimental/Robyn/issues"},"Github")),(0,i.kt)("ul",null,(0,i.kt)("li",{parentName:"ul"},"Primary channel for ",(0,i.kt)("strong",{parentName:"li"},"code issues, pull requests and bugs"),"."),(0,i.kt)("li",{parentName:"ul"},"Please ensure description is clear and has sufficient info to reproduce the issue."),(0,i.kt)("li",{parentName:"ul"},"Place to submit & contribute to the code"),(0,i.kt)("li",{parentName:"ul"},"Don\u2019t forget to sign the CLA (",(0,i.kt)("a",{parentName:"li",href:"https://code.facebook.com/cla"},"https://code.facebook.com/cla"),")")),(0,i.kt)("img",{alt:"github",src:(0,a.Z)("/img/github-issues.png")}),(0,i.kt)("p",null,"This project has a non-fixed release cycle but we will be making bug fixes in\nresponse to user feedback and adding features.\nWe appreciate all contributions. If you plan to contribute new features or\nextensions to the code, please first open an issue and discuss the feature with\nus."))}d.isMDXComponent=!0}}]);