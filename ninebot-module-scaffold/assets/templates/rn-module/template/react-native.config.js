module.exports = {
  project: {
    android: {
      unstable_reactLegacyComponentNames: [
        // list of conponents that needs to be wrapped by the interop layer
        // react-native-gesture-handler
        // 'GestureHandlerRootView',
        // 'RNGestureHandlerButton',
        // react-native-linear-gradient
        'BVLinearGradient',
        // react-native-svga
        // const NativeSVGAView = requireNativeComponent('RNSVGA', SVGAView)
        // 'RNSVGA',
        // 'SVGAView',
        // react-native-screens
        'RNSScreen',
        'RNSScreenContainer',
        'RNSScreenStack',
        'RNSModalScreen',
        'RNSScreenStackHeaderConfig',
        'RNSScreenStackHeaderSubview',
        'RNSSearchBar',
        'RNSFullWindowOverlay',
        // react-native-webview
        // 'RCTWebView',
        // @react-native-community/art 库不再维护，建议替换react-native-svg or @shopify/react-native-skia
        'ARTSurfaceView',
        'ARTGroup',
        'ARTShape',
        'ARTText',
        // @react-native-community/blur 4.4.1支持新架构
        //'BlurView',
        //'VibrancyView',
        // react-native-fast-image
        // const FastImageView = requireNativeComponent('FastImageView', FastImage, {
        'FastImageView',
        'FastImage',
        // NewcomerGuide todo
        'ReactNativeVideo',
        // TimelineModule
        'RNVideoView',
        // AuthList
        'RNAnimPlayerView',
        'RNAnimPlayerLayout',
        // flash-list
        'CellContainer',
        // react-native-video
        // const RCTVideo = requireNativeComponent('RCTVideo', Video, {
        'RCTVideo',
        'Video',
      ],
    },
    ios: {
      unstable_reactLegacyComponentNames: [
        'BVLinearGradient',
        'ARTSurfaceView',
        'ARTGroup',
        'ARTShape',
        'ARTText',
        'ReactNativeVideo',
        'RNVideoView',
        'RNAnimPlayerView',
        'RNAnimPlayerLayout',
        'CellContainer',
        'AMapCircle',
        'CircleProps',
        'AMapHeatMap',
        'HeatMapProps',
        'AMapView',
        'MapViewProps',
        'AMapMarker',
        'MarkerProps',
        'AMapMultiPoint',
        'MultiPointProps',
        'AMapPolygon',
        'Polygon',
        'AMapPolyline',
        'PolylineProps',
        'RCTVideo',
        'Video',
        'RNEasyIjkplayerView',
      ],
    },
  },
};
