package laya.d3.component {
	import laya.ani.AnimationState;
	import laya.d3.animation.AnimationClip;
	import laya.d3.animation.AnimationNode;
	import laya.d3.animation.AnimationTransform3D;
	import laya.d3.animation.Keyframe;
	import laya.d3.animation.KeyframeNode;
	import laya.d3.core.Avatar;
	import laya.d3.core.ComponentNode;
	import laya.d3.core.SkinnedMeshSprite3D;
	import laya.d3.core.Sprite3D;
	import laya.d3.core.Transform3D;
	import laya.d3.core.render.RenderState;
	import laya.d3.math.Matrix4x4;
	import laya.events.Event;
	import laya.resource.IDestroy;
	import laya.utils.Stat;
	
	/**
	 * <code>Animations</code> 类用于创建动画组件。
	 */
	public class Animator extends Component3D implements IDestroy {
		/**@private */
		private var _updateTransformPropertyLoopCount:int;
		/**@private */
		private var _cacheFrameRateInterval:Number;
		/**@private */
		private var _cacheFrameRate:int;
		/**@private */
		private var _cachePlayRate:Number;
		/**@private */
		private var _currentPlayClip:AnimationClip;
		/**@private */
		private var _currentPlayClipIndex:int;
		/**@private */
		private var _paused:Boolean;
		/**@private */
		private var _currentTime:Number;
		/**@private */
		private var _currentFrameTime:Number;
		/**@private */
		private var _currentFrameIndex:int;
		/**@private */
		private var _stopWhenCircleFinish:Boolean;
		/**@private */
		private var _elapsedPlaybackTime:Number;
		/**@private */
		private var _startUpdateLoopCount:Number;
		
		/**@private */
		private var _clipNames:Vector.<String>;
		/**@private */
		private var _clips:Vector.<AnimationClip>;
		/**@private */
		private var _playStartFrames:Vector.<Number>;
		/**@private */
		private var _playEndFrames:Vector.<Number>;
		
		/**@private */
		private var _defaultClipIndex:int;
		/**@private */
		private var _avatar:Avatar;
		/**@private */
		private var _cacheNodesOwners:Vector.<Vector.<AnimationNode>>;
		/**@private */
		private var _cacheNodesOriginalValue:Vector.<Vector.<Float32Array>>;
		/**@private */
		private var _curClipAnimationDatas:Vector.<Float32Array>;
		/**@private */
		private var _curAvatarAnimationDatas:Vector.<Matrix4x4>;
		/**@private */
		private var _publicClipAnimationDatas:Vector.<Vector.<Float32Array>>;
		/**@private */
		private var _publicAvatarAnimationDatas:Vector.<Matrix4x4>;
		/**@private */
		private var _lastPlayAnimationClip:AnimationClip;
		/**@private */
		private var _lastPlayAnimationClipIndex:int;
		
		/**@private */
		public var _cacheNodesToSpriteMap:Vector.<int>;
		/**@private */
		public var _cacheSpriteToNodesMap:Vector.<int>;
		/**@private */
		public var _cacheFullFrames:Vector.<Array>;
		/**@private */
		public var _avatarRootNode:AnimationNode;
		/**@private	*/
		public var _avatarNodeMap:Object;
		/**@private	*/
		public var _avatarNodes:Vector.<AnimationNode>;
		/**@private	*/
		public var _canCache:Boolean;
		/** @private */
		public var _lastFrameIndex:int;
		
		/**是否为缓存模式。*/
		public var isCache:Boolean;
		/** 播放速率*/
		public var playbackRate:Number;
		
		/**
		 * 获取avatar。
		 * @return avator。
		 */
		public function get avatar():Avatar {
			return _avatar;
		}
		
		/**
		 * 设置avatar。
		 * @param value avatar。
		 */
		public function set avatar(value:Avatar):void {
			if (_avatar !== value) {
				var lastAvatar:Avatar = _avatar;
				_avatar = value;
				var clipLength:int = _clips.length;
				for (var i:int = 0; i < clipLength; i++)
					_offClipAndAvatarRelateEvent(lastAvatar, _clips[i]);
				
				if (value) {
					if (value.loaded)
						_getClipsOwnersAndInitAvatarDatasAsync();
					else
						value.once(Event.LOADED, this, _getClipsOwnersAndInitAvatarDatasAsync);
				}
			}
		}
		
		/**
		 * 获取默认动画片段。
		 * @return  默认动画片段。
		 */
		public function get clip():AnimationClip {
			return _clips[_defaultClipIndex];
		}
		
		/**
		 * 设置默认动画片段,AnimationClip名称为默认playName。
		 * @param value 默认动画片段。
		 */
		public function set clip(value:AnimationClip):void {
			var index:int = value ? _clips.indexOf(value) : -1;
			if (_defaultClipIndex !== index) {
				(_defaultClipIndex !== -1) && (removeClip(_clips[_defaultClipIndex]));
				(index !== -1) && (addClip(value, value.name));
				_defaultClipIndex = index;
			}
		}
		
		/**
		 *  获取缓存播放帧，缓存模式下生效。
		 * @return	value 缓存播放帧率。
		 */
		public function get cacheFrameRate():int {
			return _cacheFrameRate;
		}
		
		/**
		 *  设置缓存播放帧率，缓存模式下生效。注意：修改此值会有计算开销。*
		 * @return	value 缓存播放帧率
		 */
		public function set cacheFrameRate(value:int):void {
			if (_cacheFrameRate !== value) {
				_cacheFrameRate = value;
				_cacheFrameRateInterval = 1.0 / _cacheFrameRate;
				
				for (var i:int = 0, n:int = _clips.length; i < n; i++)
					(_clips[i].loaded) && (_computeCacheFullKeyframeIndices(i));
			}
		}
		
		/**
		 *  获取缓存播放速率，缓存模式下生效。*
		 * @return	 缓存播放速率。
		 */
		public function get cachePlayRate():Number {
			return _cachePlayRate;
		}
		
		/**
		 *  设置缓存播放速率，缓存模式下生效。注意：修改此值会有计算开销。*
		 * @return	value 缓存播放速率。
		 */
		public function set cachePlayRate(value:Number):void {
			if (_cachePlayRate !== value) {
				_cachePlayRate = value;
				
				for (var i:int = 0, n:int = _clips.length; i < n; i++)
					(_clips[i].loaded) && (_computeCacheFullKeyframeIndices(i));
			}
		}
		
		/**
		 * 获取当前动画索引
		 * @return	value 当前动画索引
		 */
		public function get currentPlayClip():AnimationClip {
			return _currentPlayClip;
		}
		
		/**
		 * 获取当前帧数
		 * @return	 当前帧数
		 */
		public function get currentFrameIndex():int {
			return _currentFrameIndex;
		}
		
		/**
		 *  获取当前精确时间，不包括重播时间
		 * @return	value 当前时间
		 */
		public function get currentPlayTime():Number {
			return _currentTime + _playStartFrames[_currentPlayClipIndex];
		}
		
		/**
		 *  获取当前帧时间，不包括重播时间
		 * @return	value 当前时间
		 */
		public function get currentFrameTime():Number {
			return _currentFrameTime;
		}
		
		/**
		 * 获取当前是否暂停
		 * @return	是否暂停
		 */
		public function get paused():Boolean {
			return _paused;
		}
		
		/**
		 * 设置是否暂停
		 * @param	value 是否暂停
		 */
		public function set paused(value:Boolean):void {
			_paused = value;
			value && this.event(Event.PAUSED);
		}
		
		/**
		 * 获取当前播放状态
		 * @return	当前播放状态
		 */
		public function get playState():int {
			if (_currentPlayClip == null)
				return AnimationState.stopped;
			if (_paused)
				return AnimationState.paused;
			return AnimationState.playing;
		}
		
		/**
		 * 获取骨骼数据。
		 * @return 骨骼数据。
		 */
		public function get curAnimationDatas():Vector.<Float32Array> {
			return _curClipAnimationDatas;
		}
		
		/**
		 * 设置当前播放位置
		 * @param	value 当前时间
		 */
		public function set playbackTime(value:Number):void {
			if (_currentPlayClip == null || !_currentPlayClip || !_currentPlayClip.loaded)
				return;
			
			//TODO:补充该操作异常处理
			//if (value < _playStarts || value > _playEnds)
			//throw new Error("AnimationPlayer:value must large than playStartTime,small than playEndTime.");
			
			_startUpdateLoopCount = Stat.loopCount;
			var cacheFrameInterval:Number = _cacheFrameRateInterval * _cachePlayRate;
			_currentTime = value /*% playDuration*/;
			_currentFrameIndex = Math.floor(currentPlayTime / cacheFrameInterval);
			_currentFrameTime = _currentFrameIndex * cacheFrameInterval;
		}
		
		/**
		 * 创建一个 <code>Animation</code> 实例。
		 */
		public function Animator() {
			/*[DISABLE-ADD-VARIABLE-DEFAULT-VALUE]*/
			super();
			_clipNames = new Vector.<String>();
			_clips = new Vector.<AnimationClip>();
			_playStartFrames = new Vector.<Number>();
			_playEndFrames = new Vector.<Number>();
			_cacheNodesOwners = new Vector.<Vector.<AnimationNode>>();
			_cacheNodesOriginalValue = new Vector.<Vector.<Float32Array>>();
			_cacheNodesToSpriteMap = new Vector.<int>();
			_cacheSpriteToNodesMap = new Vector.<int>();
			_cacheFullFrames = new Vector.<Array>();
			_publicClipAnimationDatas = new Vector.<Vector.<Float32Array>>();
			
			_updateTransformPropertyLoopCount = -1;
			_lastFrameIndex = -1;
			_defaultClipIndex = -1;
			_cachePlayRate = 1.0;
			_currentPlayClip = null;
			_currentFrameIndex = -1;
			_currentTime = 0.0;
			_stopWhenCircleFinish = false;
			_elapsedPlaybackTime = 0;
			_startUpdateLoopCount = -1;
			isCache = true;
			cacheFrameRate = 60;
			playbackRate = 1.0;
		}
		
		/**
		 * @private
		 */
		private function _getClipOwnersAndInitRelateDatas(clipIndex:int):void {
			var frameNodes:Vector.<KeyframeNode> = _clips[clipIndex]._nodes;
			var frameNodesCount:int = frameNodes.length;
			var owners:Vector.<AnimationNode> = _cacheNodesOwners[clipIndex];
			var originalValues:Vector.<Float32Array> = _cacheNodesOriginalValue[clipIndex];
			var publicDatas:Vector.<Float32Array> = _publicClipAnimationDatas[clipIndex];
			owners.length = frameNodesCount;
			originalValues.length = frameNodesCount;
			publicDatas.length = frameNodesCount;
			var rootBone:AnimationNode = _avatarRootNode;
			
			for (var i:int = 0; i < frameNodesCount; i++) {
				var nodeOwner:AnimationNode = rootBone;
				var node:KeyframeNode = frameNodes[i];
				var path:Vector.<String> = node.path;
				for (var j:int = 0, m:int = path.length; j < m; j++) {
					var p:String = path[j];
					if (p === "") {
						break;
					} else {
						nodeOwner = nodeOwner.getChildByName(path[j]);
						if (!nodeOwner)
							break;
					}
				}
				if (!nodeOwner)
					continue;
				owners[i] = nodeOwner;
				originalValues[i] = new Float32Array(node.keyFrameWidth);
				
				var datas:Float32Array = AnimationNode._propertyGetFuncs[node.propertyNameID](nodeOwner);
				if (datas) {//不存在对应的实体节点时可能为空
					var cacheDatas:Float32Array = originalValues[i];
					for (j = 0, m = datas.length; j < m; j++)
						cacheDatas[j] = datas[j];
				}
				
				(node._cacheProperty) || (publicDatas[i] = new Float32Array(node.keyFrameWidth));//TODO:是否可以缩减队列，减少空循环
			}
		}
		
		/**
		 * @private
		 */
		private function _offClipAndAvatarRelateEvent(avatar:Avatar, clip:AnimationClip):void {
			if (avatar.loaded) {
				if (!clip.loaded)
					clip.off(Event.LOADED, this, _getClipOwnersAndInitRelateDatas);
			} else {
				avatar.off(Event.LOADED, this, _getClipsOwnersAndInitAvatarDatasAsync);
			}
		}
		
		/**
		 * @private
		 */
		private function _getClipOwnersAndInitRelateDatasAsync(clipIndex:int, clip:AnimationClip):void {
			if (clip.loaded)
				_getClipOwnersAndInitRelateDatas(clipIndex);
			else
				clip.once(Event.LOADED, this, _getClipOwnersAndInitRelateDatas, [clipIndex]);
		}
		
		/**
		 * @private
		 */
		private function _getClipsOwnersAndInitAvatarDatasAsync():void {
			for (var i:int = 0, n:int = _clips.length; i < n; i++)
				_getClipOwnersAndInitRelateDatasAsync(i, _clips[i]);
			
			_avatar._cloneDatasToAnimator(this);
			var avatarNodesCount:int = _avatarNodes.length;
			_publicAvatarAnimationDatas = new Vector.<Matrix4x4>();
			_publicAvatarAnimationDatas.length = avatarNodesCount;
			for (i = 0; i < avatarNodesCount; i++)
				_publicAvatarAnimationDatas[i] = new Matrix4x4();
			
			for (i = 0, n = _avatarNodes.length; i < n; i++)//TODO:换成字典查询
				_checkAnimationNode(_avatarNodes[i], _owner as Sprite3D);
		}
		
		/**
		 * @private
		 */
		private function _offGetClipCacheFullKeyframeIndicesEvent(clip:AnimationClip):void {
			(clip.loaded) || (clip.off(Event.LOADED, this, _computeCacheFullKeyframeIndices));
		}
		
		/**
		 * @private
		 */
		private function _computeCacheFullKeyframeIndices(clipIndex:int):void {
			var clip:AnimationClip = _clips[clipIndex];
			var cacheInterval:Number = _cacheFrameRateInterval * _cachePlayRate;
			var clipCacheFullFrames:Array = clip._getFullKeyframeIndicesWithCache(cacheInterval);
			if (clipCacheFullFrames) {
				_cacheFullFrames[clipIndex] = clipCacheFullFrames;
				return;
			} else {
				clipCacheFullFrames = _cacheFullFrames[clipIndex] = [];
				var nodes:Vector.<KeyframeNode> = clip._nodes;
				var nodeCount:int = nodes.length;
				clipCacheFullFrames.length = nodeCount;
				var frameCount:int = Math.ceil(clip._duration / cacheInterval + 0.00001) + 1;
				for (var i:int = 0; i < nodeCount; i++) {
					var node:KeyframeNode = nodes[i];
					var nodeFullFrames:Int32Array = new Int32Array(frameCount);//使用Int32Array非UInt16Array,因为需要-1表示没到第0帧的情况
					var lastFrameIndex:int = -1;
					var keyFrames:Vector.<Keyframe> = node.keyFrames;
					for (var j:int = 0, n:int = keyFrames.length; j < n; j++) {
						var keyFrame:Keyframe = keyFrames[j];
						var startTime:Number = keyFrame.startTime;
						var endTime:Number = startTime + keyFrame.duration;
						do {
							var frameIndex:int = Math.ceil(startTime / cacheInterval - 0.00001);
							for (var k:int = lastFrameIndex + 1; k < frameIndex; k++)
								nodeFullFrames[k] = -1;
							nodeFullFrames[frameIndex] = j;
							lastFrameIndex = frameIndex;
							startTime += cacheInterval;
						} while (startTime < endTime);
					}
					clipCacheFullFrames[i] = nodeFullFrames;
				}
				clip._cacheFullKeyframeIndices(cacheInterval, clipCacheFullFrames);
			}
		}
		
		/**
		 * @private
		 */
		private function _updateAnimtionPlayer():void {
			_updatePlayer(Laya.timer.delta / 1000.0);
		}
		
		/**
		 * @private
		 */
		private function _onOwnerActiveHierarchyChanged():void {
			var owner:Sprite3D = _owner as Sprite3D;
			if (owner.displayedInStage && owner.activeInHierarchy)
				Laya.timer.frameLoop(1, this, _updateAnimtionPlayer);//TODO:当前帧注册，下一帧执行
			else
				Laya.timer.clear(this, _updateAnimtionPlayer);
		}
		
		/**
		 * @private
		 */
		private function _setPlayParams(time:Number, cacheFrameInterval:Number):void {
			_currentTime = time;
			_currentFrameIndex = Math.floor(currentPlayTime / cacheFrameInterval + 0.00001);
			_currentFrameTime = _currentFrameIndex * cacheFrameInterval;
		}
		
		/**
		 * @private
		 */
		private function _setPlayParamsWhenStop(currentAniClipPlayDuration:Number, cacheFrameInterval:Number):void {
			_currentTime = currentAniClipPlayDuration;
			_currentFrameIndex = Math.floor(currentAniClipPlayDuration / cacheFrameInterval + 0.00001);
			_currentFrameTime = _currentFrameIndex * cacheFrameInterval;
			_currentPlayClip = null;//动画结束	
		}
		
		/**
		 * @private
		 */
		private function _revertKeyframeNodes(clip:AnimationClip, clipIndex:int):void {
			var originalValues:Vector.<Float32Array> = _cacheNodesOriginalValue[clipIndex];
			var frameNodes:Vector.<KeyframeNode> = clip._nodes;
			var nodeOwners:Vector.<AnimationNode> = _cacheNodesOwners[clipIndex];
			for (var i:int = 0, n:int = nodeOwners.length; i < n; i++) {
				var owner:AnimationNode = nodeOwners[i];
				(owner) && (AnimationNode._propertySetFuncs[frameNodes[i].propertyNameID](owner, originalValues[i]));
			}
		}
		
		/**
		 * @private
		 */
		private function _onAnimationStop():void {
			_lastFrameIndex = -1;
			var frameNodes:Vector.<KeyframeNode> = _currentPlayClip._nodes;
			var nodeOwners:Vector.<AnimationNode> = _cacheNodesOwners[_currentPlayClipIndex];
			for (var i:int = 0, n:int = nodeOwners.length; i < n; i++) {
				var owner:AnimationNode = nodeOwners[i];
				var frameNode:KeyframeNode = frameNodes[i];
				var keyFrames:Vector.<Keyframe> = frameNode.keyFrames;
				var endKeyframeData:Float32Array = keyFrames[keyFrames.length - 1].data;
				(owner) && (AnimationNode._propertySetFuncs[frameNode.propertyNameID](owner, endKeyframeData));
			}
		}
		
		/**
		 * @private
		 */
		private function _setAnimationClipProperty(nodeOwners:Vector.<AnimationNode>, publicClipAnimatioDatas:Vector.<Float32Array>):void {
			var nodeToCachePropertyMap:Int32Array = _currentPlayClip._nodeToCachePropertyMap;
			for (var i:int = 0, n:int = nodeOwners.length; i < n; i++) {
				var owner:AnimationNode = nodeOwners[i];
				if (owner) {
					var ketframeNode:KeyframeNode = _currentPlayClip._nodes[i];
					var datas:Float32Array = (ketframeNode._cacheProperty) ? _curClipAnimationDatas[nodeToCachePropertyMap[i]] : publicClipAnimatioDatas[i];
					(datas) && (AnimationNode._propertySetFuncs[ketframeNode.propertyNameID](owner, datas));
				}
			}
		}
		
		/**
		 * @private
		 */
		private function _setAnimationClipPropertyCache(nodeOwners:Vector.<AnimationNode>):void {
			var cachePropertyToNodeMap:Int32Array = _currentPlayClip._cachePropertyToNodeMap;
			for (var i:int = 0, n:int = cachePropertyToNodeMap.length; i < n; i++) {
				var nodexIndex:int = cachePropertyToNodeMap[i];
				var owner:AnimationNode = nodeOwners[nodexIndex];
				if (owner) {
					var ketframeNode:KeyframeNode = _currentPlayClip._nodes[nodexIndex];
					var datas:Float32Array = _curClipAnimationDatas[i];
					(datas) && (AnimationNode._propertySetFuncs[ketframeNode.propertyNameID](owner, datas));
				}
			}
		}
		
		/**
		 * @private
		 */
		private function _setAnimationClipPropertyUnCache(nodeOwners:Vector.<AnimationNode>, publicClipAnimatioDatas:Vector.<Float32Array>):void {
			var unCachePropertyToNodeMap:Int32Array = _currentPlayClip._unCachePropertyToNodeMap;
			for (var i:int = 0, n:int = unCachePropertyToNodeMap.length; i < n; i++) {
				var nodeIndex:int = unCachePropertyToNodeMap[i];
				var owner:AnimationNode = nodeOwners[nodeIndex];
				if (owner) {
					var ketframeNode:KeyframeNode = _currentPlayClip._nodes[nodeIndex];
					var datas:Float32Array = publicClipAnimatioDatas[i];
					(datas) && (AnimationNode._propertySetFuncs[ketframeNode.propertyNameID](owner, datas));
				}
			}
		}
		
		/**
		 *@private
		 */
		public function _updateAvatarNodes(avatarAnimationDatas:Vector.<Matrix4x4>):void {
			for (var i:int = 0, n:int = _cacheSpriteToNodesMap.length; i < n; i++) {
				var node:AnimationNode = _avatarNodes[_cacheSpriteToNodesMap[i]];
				var spriteTransform:Transform3D = node._transform._entity;
				var nodeTransform:AnimationTransform3D = node._transform;
				if (nodeTransform._worldUpdate) {
					var avatarWorldMatrix:Matrix4x4 = new Matrix4x4();
					avatarAnimationDatas[i] = avatarWorldMatrix;
					nodeTransform._setWorldMatrixAndUpdate(avatarWorldMatrix);
					var spriteWorldMatrix:Matrix4x4 = spriteTransform.worldMatrix;
					Matrix4x4.multiply((_owner as Sprite3D)._transform.worldMatrix, avatarWorldMatrix, spriteWorldMatrix);
					spriteTransform.worldMatrix = spriteWorldMatrix;
				}
			}
		}
		
		/**
		 *@private
		 */
		public function _updateAvatarNodesCache(avatarAnimationDatas:Vector.<Matrix4x4>):void {//TODO:if (avatarWorldMatrix)判断浪费
			for (var i:int = 0, n:int = _cacheSpriteToNodesMap.length; i < n; i++) {
				var node:AnimationNode = _avatarNodes[_cacheSpriteToNodesMap[i]];
				var spriteTransform:Transform3D = node._transform._entity;
				
				var avatarWorldMatrix:Matrix4x4 = avatarAnimationDatas[i];
				if (avatarWorldMatrix) {
					var spriteWorldMatrix:Matrix4x4 = spriteTransform.worldMatrix;
					Matrix4x4.multiply((_owner as Sprite3D)._transform.worldMatrix, avatarWorldMatrix, spriteWorldMatrix);
					spriteTransform.worldMatrix = spriteWorldMatrix;
				}
			}
		}
		
		/**
		 * @private
		 */
		public function _updatePlayer(elapsedTime:Number):void {
			if (_currentPlayClip == null || _paused || !_currentPlayClip.loaded)//动画停止或暂停，不更新
				return;
			
			var cacheFrameInterval:Number = _cacheFrameRateInterval * _cachePlayRate;
			var time:Number = 0;
			(_startUpdateLoopCount !== Stat.loopCount) && (time = elapsedTime * playbackRate, _elapsedPlaybackTime += time);
			
			var frameRate:Number = _currentPlayClip._frameRate;
			var playStart:Number = _playStartFrames[_currentPlayClipIndex] / frameRate;
			var playEnd:Number = Math.min(_playEndFrames[_currentPlayClipIndex] / frameRate, _currentPlayClip._duration);
			
			var currentAniClipPlayDuration:Number = playEnd - playStart;
			if ((!_currentPlayClip.islooping && _elapsedPlaybackTime >= currentAniClipPlayDuration)) {
				_onAnimationStop();
				_setPlayParamsWhenStop(currentAniClipPlayDuration, cacheFrameInterval);
				this.event(Event.STOPPED);
				return;
			}
			time += _currentTime;
			if (currentAniClipPlayDuration > 0) {
				if (time >= currentAniClipPlayDuration) {
					do {//TODO:用求余改良
						time -= currentAniClipPlayDuration;
						if (_stopWhenCircleFinish) {
							_stopWhenCircleFinish = false;
							_onAnimationStop();
							_setPlayParamsWhenStop(currentAniClipPlayDuration, cacheFrameInterval);
							this.event(Event.STOPPED);
							return;
						}
						
						if (time < currentAniClipPlayDuration) {
							_setPlayParams(time, cacheFrameInterval);
							this.event(Event.COMPLETE);
						}
						
					} while (time >= currentAniClipPlayDuration)
				} else {
					_setPlayParams(time, cacheFrameInterval);
				}
			} else {
				if (_stopWhenCircleFinish) {
					_stopWhenCircleFinish = false;
					_onAnimationStop();
					_setPlayParamsWhenStop(currentAniClipPlayDuration, cacheFrameInterval);
					this.event(Event.STOPPED);
					return;
				}
				_currentTime = _currentFrameTime = _currentFrameIndex = 0;
				this.event(Event.COMPLETE);
			}
		}
		
		/**
		 * @private
		 */
		public function _updateTansformProperty():void {
			if (_updateTransformPropertyLoopCount === Stat.loopCount)
				return;
			
			var publicDatas:Vector.<Float32Array> = _publicClipAnimationDatas[_currentPlayClipIndex];
			currentPlayClip._evaluateAnimationlDatasCacheFrame(_cacheFullFrames[_currentPlayClipIndex], this, publicDatas, null, _cacheNodesOwners[_currentPlayClipIndex]);
			_setAnimationClipPropertyUnCache(_cacheNodesOwners[_currentPlayClipIndex], publicDatas);
		}
		
		/**
		 * @private
		 * 更新蒙皮动画组件。
		 * @param	state 渲染状态参数。
		 */
		public override function _update(state:RenderState):void {
			var clip:AnimationClip = _currentPlayClip;
			if (playState !== AnimationState.playing || !clip || !clip.loaded)
				return;
			
			var i:int, n:int;
			var rate:Number = playbackRate * Laya.timer.scale;
			var cacheRate:Number = _cachePlayRate;
			_canCache = isCache && rate >= cacheRate;
			var frameIndex:int = -1;
			if (_canCache) {
				frameIndex = _currentFrameIndex;
				if (_lastFrameIndex === frameIndex)
					return;
				
				var cachedAvatarAniDatas:Vector.<Matrix4x4> = clip._getAvatarDataWithCache(_avatar, _cachePlayRate, frameIndex);
				if (cachedAvatarAniDatas) {//如果cachedAvatarAniDatas存在,cachedClipAniDatas一定存在
					_curClipAnimationDatas = clip._getAnimationDataWithCache(cacheRate, frameIndex);
					_setAnimationClipPropertyCache(_cacheNodesOwners[_currentPlayClipIndex]);
					_updateAvatarNodesCache(cachedAvatarAniDatas);
					_lastFrameIndex = frameIndex;
					return;
				}
				
				var nodeOwners:Vector.<AnimationNode> = _cacheNodesOwners[_currentPlayClipIndex];
				var publicClipAnimationDatas:Vector.<Float32Array> = _publicClipAnimationDatas[_currentPlayClipIndex];
				_curClipAnimationDatas = clip._getAnimationDataWithCache(cacheRate, frameIndex);
				if (_curClipAnimationDatas) {
					clip._evaluateAnimationlDatasCacheFrame(_cacheFullFrames[_currentPlayClipIndex], this, publicClipAnimationDatas, null, nodeOwners);
					_setAnimationClipProperty(nodeOwners, publicClipAnimationDatas);
				} else {
					var cachePropertyToNodeMap:Int32Array = clip._cachePropertyToNodeMap;
					_curClipAnimationDatas = new Vector.<Float32Array>();
					_curClipAnimationDatas.length = cachePropertyToNodeMap.length;
					clip._evaluateAnimationlDatasCacheFrame(_cacheFullFrames[_currentPlayClipIndex], this, publicClipAnimationDatas, _curClipAnimationDatas, nodeOwners);
					_setAnimationClipProperty(nodeOwners, publicClipAnimationDatas);
					clip._cacheAnimationData(cacheRate, frameIndex, _curClipAnimationDatas);
				}
				
				_curAvatarAnimationDatas = new Vector.<Matrix4x4>();
				_curAvatarAnimationDatas.length = _cacheSpriteToNodesMap.length;
				_updateAvatarNodes(_curAvatarAnimationDatas);
				clip._cacheAvatarData(_avatar, cacheRate, frameIndex, _curAvatarAnimationDatas);
				_updateTransformPropertyLoopCount = Stat.loopCount;
			} else {
				_curClipAnimationDatas = _publicClipAnimationDatas[_currentPlayClipIndex];
				_curAvatarAnimationDatas = _publicAvatarAnimationDatas;
				clip._evaluateAnimationlDatasRealTime(currentPlayTime, _curClipAnimationDatas);
				_setAnimationClipProperty(_cacheNodesOwners[_currentPlayClipIndex], _curClipAnimationDatas);
				_updateAvatarNodes(_curAvatarAnimationDatas);
			}
			
			_lastFrameIndex = frameIndex;
		}
		
		/**
		 * @private
		 */
		private function _checkAnimationNode(node:AnimationNode, sprite:Sprite3D):void {
			if (node.name === sprite.name && !sprite._transform.dummy)//判断!sprite._transform.dummy重名节点可按顺序依次匹配。
				sprite._associateSpriteToAnimationNode(_avatar, node);
			
			for (var i:int = 0, n:int = sprite._childs.length; i < n; i++)
				_checkAnimationNode(node, sprite.getChildAt(i) as Sprite3D);
		}
		
		/**
		 * @inheritDoc
		 */
		override public function _load(owner:ComponentNode):void {
			//(_owner.activeInHierarchy) && (Laya.timer.frameLoop(1, this, _updateAnimtionPlayer));
			_owner.on(Event.DISPLAY, this, _onOwnerActiveHierarchyChanged);
			_owner.on(Event.UNDISPLAY, this, _onOwnerActiveHierarchyChanged);
			_owner.on(Event.ACTIVE_IN_HIERARCHY_CHANGED, this, _onOwnerActiveHierarchyChanged);//TODO:Stop和暂停的时候也要移除
		}
		
		/**
		 * @inheritDoc
		 */
		override public function _unload(owner:ComponentNode):void {
			super._unload(owner);
			_curClipAnimationDatas = null;
			_publicClipAnimationDatas = null;
			_curAvatarAnimationDatas = null;
			_publicAvatarAnimationDatas = null;
		}
		
		/**
		 * @private
		 */
		override public function _destroy():void {
			super._destroy();
			_currentPlayClip = null;
			
			_clipNames = null;
			_cacheNodesOwners = null;
			_cacheNodesOriginalValue = null;
			_publicClipAnimationDatas = null;
			_clips = null;
			_cacheFullFrames = null;
		}
		
		/**
		 * @private
		 */
		override public function _cloneTo(dest:Component3D):void {
			var animator:Animator = dest as Animator;
			animator.avatar = avatar;
			var clipCount:int = _clips.length;
			for (var i:int = 0, n:int = _clips.length; i < n; i++)
				animator.addClip(_clips[i]);
			animator.clip = clip;
			animator.play();//TODO:
		}
		
		/**
		 * 添加动画片段。
		 * @param	clip 动画片段。
		 * @param	playName 动画片段播放名称，如果为null,则使用clip.name作为播放名称。
		 * @param   开始帧率。
		 * @param   结束帧率。
		 */
		public function addClip(clip:AnimationClip, playName:String = null, startFrame:int = 0, endFrame:int = 4294967295/*uint.MAX_VALUE*/):void {
			playName = playName || clip.name;
			var index:int = _clipNames.indexOf(playName);
			if (index !== -1) {
				if (_clips[index] !== clip)
					throw new Error("Animation:this playName has exist with another clip.");
			} else {
				var clipIndex:int = _clips.indexOf(clip);
				if (clipIndex !== -1)
					throw new Error("Animation:this clip has exist with another playName.");
				
				if (startFrame < 0 || endFrame < 0)
					throw new Error("Animator:startFrame and endFrame must large than zero.");
				
				if (startFrame > endFrame)
					throw new Error("Animator:startFrame must less than endFrame.");
				
				_clipNames.push(playName);
				_clips.push(clip);
				_playStartFrames.push(startFrame);
				_playEndFrames.push(endFrame);
				_cacheNodesOwners.push(new Vector.<Sprite3D>());
				_cacheNodesOriginalValue.push(new Vector.<Float32Array>());
				_publicClipAnimationDatas.push(new Vector.<Float32Array>());
				
				clipIndex = _clips.length - 1;
				if (_avatar) {
					if (_avatar.loaded)
						_getClipOwnersAndInitRelateDatasAsync(clipIndex, clip);
					else
						_avatar.once(Event.LOADED, this, _getClipOwnersAndInitRelateDatasAsync, [clipIndex, clip]);
				}
				
				if (clip.loaded)
					_computeCacheFullKeyframeIndices(clipIndex);
				else
					clip.once(Event.LOADED, this, _computeCacheFullKeyframeIndices, [clipIndex]);
			}
		}
		
		/**
		 * 移除动画片段。
		 * @param	clip 动画片段。
		 */
		public function removeClip(clip:AnimationClip):void {
			var index:int = _clips.indexOf(clip);
			if (index !== -1) {
				(_avatar) && (_offClipAndAvatarRelateEvent(_avatar, clip));
				_offGetClipCacheFullKeyframeIndicesEvent(clip);
				
				_clipNames.splice(index, 1);
				_clips.splice(index, 1);
				_playStartFrames.splice(index, 1);
				_playEndFrames.splice(index, 1);
				_cacheNodesOwners.splice(index, 1);
				_cacheNodesOriginalValue.splice(index, 1);
				_publicClipAnimationDatas.splice(index, 1);
			}
		}
		
		/**
		 * 通过播放名字移除动画片段。
		 * @param	playName 播放名字。
		 */
		public function removeClipByName(playName:String):void {
			var index:int = _clipNames.indexOf(playName);
			if (index !== -1) {
				var clip:AnimationClip = _clips[index];
				(_avatar) && (_offClipAndAvatarRelateEvent(_avatar, clip));
				_offGetClipCacheFullKeyframeIndicesEvent(clip);
				
				_clipNames.splice(index, 1);
				_clips.splice(index, 1);
				_playStartFrames.splice(index, 1);
				_playEndFrames.splice(index, 1);
				_cacheNodesOwners.splice(index, 1);
				_cacheNodesOriginalValue.splice(index, 1);
				_publicClipAnimationDatas.splice(index, 1);
			}
		}
		
		/**
		 * 通过播放名字获取动画片段。
		 * @param	playName 播放名字。
		 * @return 动画片段。
		 */
		public function getClip(playName:String):AnimationClip {
			var index:int = _clipNames.indexOf(playName);
			if (index !== -1) {
				return _clips[index];
			} else {
				return null;
			}
		}
		
		/**
		 * 获取动画片段个数。
		 * @return	动画个数。
		 */
		public function getClipCount():int {
			return _clips.length;
		}
		
		/**
		 * 播放动画。
		 * @param	name 如果为null则播放默认动画，否则按名字播放动画片段。
		 * @param	playbackRate 播放速率。
		 * @param	startFrame 开始帧率。
		 * @param	endFrame 结束帧率.-1表示为最大结束帧率。
		 */
		public function play(name:String = null, playbackRate:Number = 1.0):void {
			if (!name && _defaultClipIndex == -1)
				throw new Error("Animator:must have  default clip value,please set clip property.");
			
			if (name) {
				_currentPlayClipIndex = _clipNames.indexOf(name);
				_currentPlayClip = _clips[_currentPlayClipIndex];
			} else {
				_currentPlayClipIndex = _defaultClipIndex;
				_currentPlayClip = _clips[_defaultClipIndex];
			}
			
			_currentTime = 0;
			_currentFrameTime = 0;
			_elapsedPlaybackTime = 0;
			this.playbackRate = playbackRate;
			_paused = false;
			
			_currentFrameIndex = 0;
			_startUpdateLoopCount = Stat.loopCount;
			
			this.event(Event.PLAYED);
			if (_lastPlayAnimationClip) {
				(_lastPlayAnimationClip !== _currentPlayClip) && (_revertKeyframeNodes(_lastPlayAnimationClip, _lastPlayAnimationClipIndex));//TODO:还原动画节点，防止切换动作时跳帧，如果是从stop而来是否无需设置
			}
			
			//TODO:此处是否直接设置一帧最接近的原始帧率,后面AnimationClip首帧可以设置为null了就
			_updatePlayer(0);//如果分段播放,可修正帧率
			_lastPlayAnimationClip = _currentPlayClip;
			_lastPlayAnimationClipIndex = _currentPlayClipIndex;
		}
		
		/**
		 * 停止播放当前动画
		 * @param	immediate 是否立即停止
		 */
		public function stop(immediate:Boolean = true):void {
			if (playState !== AnimationState.stopped) {
				if (immediate) {
					_onAnimationStop();
					_currentTime = _currentFrameTime = _currentFrameIndex = 0;
					_currentPlayClip = null;
					this.event(Event.STOPPED);
				} else {
					_stopWhenCircleFinish = true;
				}
			}
		}
		
		/**
		 * 关联精灵节点到动画节点,该精灵必须在此Animator下。
		 * @param nodeName 关联节点的名字。
		 * @param sprite3D 精灵节点。
		 * @return 是否关联成功。
		 */
		public function linkSprite3D(nodeName:String, sprite3D:Sprite3D):Boolean {
			var node:AnimationNode = _avatarNodeMap[nodeName];
			if (node) {
				if (this !== sprite3D._belongAnimator)
					throw new Error("Animator:The link Sprite3D's belong Animator must be same as this.");
				sprite3D._associateSpriteToAnimationNode(_avatar, node);
				return true;
			} else {
				return false;
			}
		}
	}

}