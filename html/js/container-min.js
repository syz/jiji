if(typeof container=="undefined"){container={}}container.VERSION="0.3.0";container.Container=function(B){var A=new container.Binder({});B(A);this.defs=A.defs;this.creating=[];this.typeCache={};this.nameCache={};var C=this;this.eachComponentDef(function(E){if(E&&E[container.Annotation.Container]&&E[container.Annotation.Container][container.Annotation.Scope]==container.Scope.EagerSingleton){C.create(E)}if(E&&E[container.Annotation.Container]&&E[container.Annotation.Container][container.Annotation.Name]){var D=E[container.Annotation.Container][container.Annotation.Name];if(!C.nameCache[D]){C.nameCache[D]=[]}C.nameCache[D].push(E)}})};container.Container.prototype={get:function(A){if(A instanceof container.Type){if(!this.typeCache[A]){this._createTypeCahce(A)}if(this.typeCache[A].length>0){return this.create(this.typeCache[A][0])}else{throw container.createError(new Error(),container.ErrorCode.ComponentNotFound,"compoent not found.",{"type":A})}}else{if(this.nameCache[A]&&this.nameCache[A].length>0){return this.create(this.nameCache[A][0])}else{throw container.createError(new Error(),container.ErrorCode.ComponentNotFound,"compoent not found.",{"name":A})}}},gets:function(D){var C=[];if(D instanceof container.Type){if(!this.typeCache[D]){this._createTypeCahce(D)}var A=this.typeCache[D];for(var B=0;B<A.length;B++){C.push(this.create(A[B]))}}else{if(this.nameCache[D]){var A=this.nameCache[D];for(var B=0;B<A.length;B++){C.push(this.create(A[B]))}}}return C},destroy:function(){var A=this;this.eachComponentDef(function(D){if(!D.instance){return }var E=D.instance;var B=D[container.Annotation.Container];if(!B||!B[container.Annotation.Destroy]){return }var C=B[container.Annotation.Destroy];if(typeof C=="string"){E[C].apply(E,[this])}else{if(typeof C=="function"){C(E,A)}else{throw container.createError(new Error(),container.ErrorCode.IllegalDefinition,"illegal destroy method. string or function is supported.",{"def":D})}}D.instance=null})},create:function(A){if(A.instance){return A.instance}if(this._isCreating(A)){throw container.createError(new Error(),container.ErrorCode.CircularReference,"circulative component creation.",{"def":A})}try{this.creating.push(A);var E=A.constractor(this);A.instance=E;var C=A[container.Annotation.Container]||{};if(C[container.Annotation.Inject]){var H=C[container.Annotation.Inject];for(var I in H){if(H[I] instanceof container.inner.Component){E[I]=this.get(H[I].name)}else{if(H[I] instanceof container.inner.Components){E[I]=this.gets(H[I].name)}else{if(H[I] instanceof container.inner.Provider){E[I]=H[I].func(E,this)}else{E[I]=H[I]}}}}}if(C[container.Annotation.Initialize]){var G=C[container.Annotation.Initialize];if(typeof G=="string"){E[G].apply(E,[this])}else{if(typeof G=="function"){G(E,this)}else{throw container.createError(new Error(),container.ErrorCode.IllegalDefinition,"illegal initialize method. string or function is supported.",{"def":A})}}}if(C[container.Annotation.Intercept]){var B=C[container.Annotation.Intercept];for(var F=0;F<B.length;F++){this.applyInterceptor(E,B[F][0],B[F][1])}}if(this.defs.interceptors&&A.componentType!="function"){for(var F=0;F<this.defs.interceptors.length;F++){var D=this.defs.interceptors[F];if(!D.nameMatcher){continue}if(D.nameMatcher instanceof container.Type&&D.nameMatcher.isImplementor(E)){this.applyInterceptor(E,D.interceptor,D.methodMatcher)}else{if(D.nameMatcher instanceof container.Matcher&&C[container.Annotation.Name]&&D.nameMatcher.match(C[container.Annotation.Name])){this.applyInterceptor(E,D.interceptor,D.methodMatcher)}}}}if(C[container.Annotation.Scope]==container.Scope.Prototype){A.instance=undefined}return E}catch(J){A.instance=undefined;throw J}finally{this.creating.pop()}},applyInterceptor:function(D,C,B){if(!C||!B){return }for(var A in D){if(typeof D[A]=="function"&&B.match(A)){(function(){var E=A;var F=D[E];D[E]=function(){var G=new container.MethodInvocation(E,F,D,arguments);return C(G)}})()}}},eachComponentDef:function(B){for(var A=0;A<this.defs.objects.length;A++){if(B){B.apply(null,[this.defs.objects[A]])}}},_createTypeCahce:function(C){var B=[];var A=this;this.eachComponentDef(function(D){if(A._isCreating(D)&&!D.instance){return }var E=A.create(D);if(C.isImplementor(E)){B.push(D)}});this.typeCache[C]=B},_isCreating:function(B){for(var A=0;A<this.creating.length;A++){if(B===this.creating[A]){return true}}return false}};container.Binder=function(A,B){this.defs=A;this.namespace=B};container.Binder.prototype={bind:function(A){return this._bind("object",A.prototype.meta,function(){return new A()})},bindMethod:function(C,B){var A=this;return this._bind("function",null,function(D){var E=D.get(C);if(!E){throw D.createError(new Error(),D.ErrorCode.ComponentNotFound,"component not found.",{"name":name})}return A._createBindMethod(E,B)})},bindMethods:function(C,B){var A=this;return this._bind("function",null,function(D){var G=D.gets(C);var F=[];for(var E=0;E<G.length;E++){F.push(A._createBindMethod(G[E],B))}return F})},bindProvider:function(A){return this._bind("object",null,A)},bindInstance:function(A){return this._bind("object",A.meta,function(){return A})},bindInterceptor:function(D,A,B){var C=this._getInterceptorDefs();C.push({"interceptor":D,"nameMatcher":A,"methodMatcher":B})},ns:function(B,A){if(this.namespace){B=this.namespace+"."+B}A(new container.Binder(this.defs,B))},_bind:function(A,E,B){var D=this._clone(E);D.constractor=B;D.componentType=A;var C=this._getObjectDefs();C.push(D);return new container.Builder(D,this.namespace)},_getObjectDefs:function(){if(!this.defs.objects){this.defs.objects=[]}return this.defs.objects},_getInterceptorDefs:function(){if(!this.defs.interceptors){this.defs.interceptors=[]}return this.defs.interceptors},_createBindMethod:function(B,A){return function(){return B[A].apply(B,arguments)}},_clone:function(F){var C={};if(F&&F[container.Annotation.Container]){F=F[container.Annotation.Container];var E=[container.Annotation.Name,container.Annotation.Inject,container.Annotation.Initialize,container.Annotation.Destroy,container.Annotation.Scope];for(var B=0;B<E.length;B++){C[E[B]]=F[E[B]]}C[container.Annotation.Intercept]=[];if(F[container.Annotation.Intercept]){var D=F[container.Annotation.Intercept];for(var B=0;B<D.length;B++){C[container.Annotation.Intercept].push(D[B])}}}var A={};A[container.Annotation.Container]=C;return A}};container.Builder=function(B,A){if(!B[container.Annotation.Container]){B[container.Annotation.Container]={}}this.def=B[container.Annotation.Container];if(!this.def[container.Annotation.Intercept]){this.def[container.Annotation.Intercept]=[]}this.namespace=A};container.Builder.prototype={to:function(A){if(this.namespace){A=this.namespace+"."+A}this.def[container.Annotation.Name]=A;return this},inject:function(A){this.def[container.Annotation.Inject]=A;return this},initialize:function(A){this.def[container.Annotation.Initialize]=A;return this},destroy:function(A){this.def[container.Annotation.Destroy]=A;return this},scope:function(A){this.def[container.Annotation.Scope]=A;return this},intercept:function(B,A){this.def[container.Annotation.Intercept].push([B,A]);return this}};container.Matcher=function(A,B){if(A&&!(A instanceof Array||A instanceof RegExp||A instanceof Function)){throw container.createError(new Error(),container.ErrorCode.IllegalArgument,"Illegal includes.",{})}if(B&&!(B instanceof Array||B instanceof RegExp||B instanceof Function)){throw container.createError(new Error(),container.ErrorCode.IllegalArgument,"Illegal excludes.",{})}this.excludes=B;this.includes=A};container.Matcher.prototype={match:function(A){if(this.excludes&&this.getEvaluator(this.excludes)(A)){return false}if(this.includes&&this.getEvaluator(this.includes)(A)){return true}return false},getEvaluator:function(A){if(A instanceof Array){return function(C){for(var B=0;B<A.length;B++){if(A[B] instanceof RegExp&&A[B].test(C)){return true}}return false}}else{if(A instanceof RegExp){return function(B){return A.test(B)}}else{if(A instanceof Function){return A}}}}};container.MethodInvocation=function(B,C,D,A){this.name=B;this.original=C;this.arg=A;this.target=D};container.MethodInvocation.prototype={getThis:function(){return this.target},proceed:function(){return this.original.apply(this.target,this.arg)},getArguments:function(){return this.arg},getOriginalMethod:function(){return this.original},getMethodName:function(){return this.name}};container.inner={};container.inner.Component=function(A){this.name=A};container.inner.Components=function(A){this.name=A};container.inner.Provider=function(A){this.func=A};container.createError=function(B,D,C,A){B.errorCode=D;B.message=C;B.options=A;B.name="container.Exception";return B};container.ErrorCode={IllegalArgument:1,ComponentNotFound:100,IllegalDefinition:101,CircularReference:102};container.Annotation={Container:"@Container",Name:"@Name",Inject:"@Inject",Initialize:"@Initialize",Destroy:"@Destroy",Intercept:"@Intercept",Scope:"@Scope"};container.Scope={Singleton:"Singleton",Prototype:"Prototype",EagerSingleton:"EagerSingleton"};container.any=function(){return new container.Matcher(/.*/)};container.component=function(A){return new container.inner.Component(A)};container.components=function(A){return new container.inner.Components(A)};container.provides=function(A){return new container.inner.Provider(A)};container.Type=function(){};container.Type.prototype={equals:function(A){},isImplementor:function(A){}};container.types={has:function(){return new container.inner.types.And(container.types._createTypes(arguments))},hasAny:function(){return new container.inner.types.Or(container.types._createTypes(arguments))},not:function(A){return new container.inner.types.Not(container.types._createType(A))},_createTypes:function(C){var B=[];for(var A=0;A<C.length;A++){B.push(container.types._createType(C[A]))}return B},_createType:function(A){if(A instanceof RegExp){return new container.inner.types.RegexpMethod(A)}else{if(A instanceof container.Type){return A}else{if(typeof A=="string"){return new container.inner.types.Method(A)}else{throw"illegal argument."}}}}};container.inner.types={};container.inner.types.Method=function(A){this.name=A};container.inner.types.Method.prototype=new container.Type();container.inner.types.Method.prototype.equals=function(A){if(!A||!(A instanceof container.inner.types.Method)){return false}return this.name==A.name};container.inner.types.Method.prototype.isImplementor=function(A){return typeof A[this.name]=="function"};container.inner.types.Method.prototype.toString=function(){return"!container.inner.types.Method:"+this.name};container.inner.types.RegexpMethod=function(A){this.exp=A};container.inner.types.RegexpMethod.prototype=new container.Type();container.inner.types.RegexpMethod.prototype.equals=function(A){if(!A||!(A instanceof container.inner.types.RegexpMethod)){return false}return this.exp.ignoreCase==A.exp.ignoreCase&&this.exp.global==A.exp.global&&this.exp.source==A.exp.source};container.inner.types.RegexpMethod.prototype.isImplementor=function(B){for(var A in B){if(typeof B[A]=="function"&&this.exp.test(A)){return true}}return false};container.inner.types.RegexpMethod.prototype.toString=function(){return"!container.inner.types.RegexpMethod:/"+this.exp.source+"/"+this.exp.ignoreCase+"/"+this.exp.global};container.inner.types.And=function(A){this.types=A};container.inner.types.And.prototype=new container.Type();container.inner.types.And.prototype.equals=function(D){if(!D||!(D instanceof container.inner.types.And)){return false}if(this.types.length!=D.types.length){return false}for(var C=0;C<this.types.length;C++){var B=this.types[C];var A=D.types[C];if(!B.equals(A)){return false}}return true};container.inner.types.And.prototype.isImplementor=function(B){for(var A=0;A<this.types.length;A++){if(!this.types[A].isImplementor(B)){return false}}return true};container.inner.types.And.prototype.toString=function(){var B="!container.inner.types.And:[";for(var A=0;A<this.types.length;A++){B+=this.types[A].toString()+","}B+="]";return B};container.inner.types.Or=function(A){this.types=A};container.inner.types.Or.prototype=new container.Type();container.inner.types.Or.prototype.equals=function(D){if(!D||!(D instanceof container.inner.types.Or)){return false}if(this.types.length!=D.types.length){return false}for(var C=0;C<this.types.length;C++){var B=this.types[C];var A=D.types[C];if(!B.equals(A)){return false}}return true};container.inner.types.Or.prototype.isImplementor=function(B){for(var A=0;A<this.types.length;A++){if(this.types[A].isImplementor(B)){return true}}return false};container.inner.types.Or.prototype.toString=function(){var B="!container.inner.types.Or:[";for(var A=0;A<this.types.length;A++){B+=this.types[A].toString()+","}B+="]";return B};container.inner.types.Not=function(A){this.type=A};container.inner.types.Not.prototype=new container.Type();container.inner.types.Not.prototype.equals=function(A){if(!A||!(A instanceof container.inner.types.Not)){return false}return this.type.equals(A.type)};container.inner.types.Not.prototype.isImplementor=function(A){return !this.type.isImplementor(A)};container.inner.types.Not.prototype.toString=function(){return"!container.inner.types.Not:["+this.type.toString()+"]"}