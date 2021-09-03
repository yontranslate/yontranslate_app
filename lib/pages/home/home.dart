import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:screen_text_extractor/screen_text_extractor.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

import '../../../includes.dart';

export './limited_functionality_banner.dart';
export './new_version_found_banner.dart';
import './toolbar_item_always_on_top.dart';
import './toolbar_item_settings.dart';
import './toolbar_item_sponsor.dart';
import './translation_input_view.dart';
import './translation_results_view.dart';
import './translation_target_select_view.dart';

const kMenuItemIdShowOrHideMainWindow = 'show-or-hide-main-window';
const kMenuItemIdExitApp = 'exit-app';

class HomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TrayListener, WindowListener, UriSchemeListener {
  FocusNode _focusNode = FocusNode();
  TextEditingController _textEditingController = TextEditingController();
  ScrollController _scrollController = ScrollController();

  GlobalKey _bannersViewKey = GlobalKey();
  GlobalKey _inputViewKey = GlobalKey();
  GlobalKey _resultsViewKey = GlobalKey();

  Config _config = sharedConfigManager.getConfig();

  PackageInfo _packageInfo;
  Version _latestVersion;
  bool _isAllowedScreenCaptureAccess = true;
  bool _isAllowedScreenSelectionAccess = true;

  String _sourceLanguage = kLanguageEN;
  String _targetLanguage = kLanguageZH;
  bool _isShowSourceLanguageSelector = false;
  bool _isShowTargetLanguageSelector = false;

  bool _querySubmitted = false;
  String _text = '';
  String _textDetectedLanguage;
  ExtractedData _extractedData;
  List<TranslationResult> _translationResultList = [];

  List<Future> _futureList = [];

  Timer _resizeTimer;

  List<TranslationEngineConfig> get _translationEngineList {
    return sharedLocalDb.engines.list(
      where: (e) => !e.disabled,
    );
  }

  List<TranslationTarget> get _translationTargetList {
    if (_config.translationMode == kTranslationModeManual) {
      return [
        TranslationTarget(
          sourceLanguage: _sourceLanguage,
          targetLanguage: _targetLanguage,
        ),
      ];
    }
    return sharedLocalDb.translationTargets.list();
  }

  @override
  void initState() {
    UriSchemeManager.instance.addListener(this);
    trayManager.addListener(this);
    windowManager.addListener(this);
    sharedConfigManager.addListener(_configListen);
    _init();
    _loadData();
    super.initState();
  }

  @override
  void dispose() {
    UriSchemeManager.instance.removeListener(this);
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    sharedConfigManager.removeListener(_configListen);
    super.dispose();
  }

  void _configListen() {
    _config = sharedConfigManager.getConfig();
    setState(() {});
  }

  void _init() async {
    _packageInfo = await PackageInfo.fromPlatform();

    if (kIsMacOS) {
      _isAllowedScreenCaptureAccess =
          await screenTextExtractor.isAllowedScreenCaptureAccess();
      _isAllowedScreenSelectionAccess =
          await screenTextExtractor.isAllowedScreenSelectionAccess();
    }

    // 初始化托盘图标
    if (kIsMacOS) {
      trayManager.setIcon(R.image('tray_icon.png'));
      trayManager.setContextMenu([
        MenuItem(
          identifier: kMenuItemIdShowOrHideMainWindow,
          title: '显示主窗口',
        ),
        MenuItem.separator,
        MenuItem(
          identifier: kMenuItemIdExitApp,
          title: '退出',
        ),
      ]);
    }

    // 初始化快捷键
    if (!kIsLinux) {
      hotKeyManager.unregisterAll();
      hotKeyManager.register(
        _config.shortcutInputSettingSubmitWithMetaEnter,
        keyDownHandler: (_) {
          if (_config.inputSetting != kInputSettingSubmitWithMetaEnter) {
            return;
          }
          _handleButtonTappedTrans();
        },
      );
      hotKeyManager.register(
        _config.shortcutShowOrHide,
        keyDownHandler: (_) async {
          bool isVisible = await windowManager.isVisible();
          if (isVisible) {
            _windowHide();
          } else {
            _windowShow();
          }
        },
      );
      hotKeyManager.register(
        _config.shortcutExtractFromScreenSelection,
        keyDownHandler: (_) {
          _handleExtractTextFromScreenSelection();
        },
      );
      hotKeyManager.register(
        _config.shortcutExtractFromScreenCapture,
        keyDownHandler: (_) {
          _handleExtractTextFromScreenCapture();
        },
      );
    }
  }

  Future<void> _windowShow() async {
    if (!kIsMacOS) return;

    Size windowSize = await windowManager.getSize();
    Rect trayIconBounds = await trayManager.getBounds();
    Size trayIconSize = trayIconBounds.size;
    Offset trayIconnewPosition = trayIconBounds.topLeft;

    Offset newPosition = Offset(
      trayIconnewPosition.dx - ((windowSize.width - trayIconSize.width) / 2),
      trayIconnewPosition.dy,
    );

    bool isAlwaysOnTop = await windowManager.isAlwaysOnTop();
    if (!isAlwaysOnTop) {
      windowManager.setPosition(newPosition);
      await Future.delayed(Duration(milliseconds: 100));
    }
    windowManager.show();
  }

  void _windowHide() {
    windowManager.hide();
  }

  void _resizeWindow() {
    if (Navigator.of(context).canPop()) return;

    if (_resizeTimer != null && _resizeTimer.isActive) {
      _resizeTimer.cancel();
    }
    _resizeTimer = Timer.periodic(Duration(milliseconds: 10), (_) async {
      RenderBox rb1 = _bannersViewKey?.currentContext?.findRenderObject();
      RenderBox rb2 = _inputViewKey?.currentContext?.findRenderObject();
      RenderBox rb3 = _resultsViewKey?.currentContext?.findRenderObject();

      double toolbarViewHeight = 36.0 + (kIsWindows ? 34 : 0);
      double bannersViewHeight = rb1?.size?.height ?? 0;
      double inputViewHeight = rb2?.size?.height ?? 0;
      double resultsViewHeight = rb3?.size?.height ?? 0;

      try {
        Size oldSize = await windowManager.getSize();
        Size newSize = Size(
          oldSize.width,
          toolbarViewHeight +
              bannersViewHeight +
              inputViewHeight +
              resultsViewHeight,
        );
        if (oldSize.width != newSize.width ||
            oldSize.height != newSize.height) {
          windowManager.setSize(newSize, animate: true);
        }
      } catch (error) {
        print(error);
      }

      if (_resizeTimer != null) {
        _resizeTimer.cancel();
        _resizeTimer = null;
      }
    });
  }

  void _loadData() async {
    try {
      await sharedLocalDb.loadPro();
      _latestVersion = await sharedApiClient.version('latest').get();
      setState(() {});
    } catch (error) {
      print(error);
    }
  }

  void _queryData() async {
    setState(() {
      _isShowSourceLanguageSelector = false;
      _isShowTargetLanguageSelector = false;
      _querySubmitted = true;
      _textDetectedLanguage = null;
      _translationResultList = [];
      _futureList = [];
    });

    if (_config.translationMode == kTranslationModeManual) {
      TranslationResult translationResult = TranslationResult(
        translationTarget: _translationTargetList.first,
        translationResultRecordList: [],
      );
      _translationResultList = [translationResult];
    } else {
      var filteredTranslationTargetList = _translationTargetList;
      try {
        DetectLanguageRequest detectLanguageRequest = DetectLanguageRequest(
          texts: [_text],
        );
        DetectLanguageResponse detectLanguageResponse =
            await sharedTranslateClient
                .use(sharedConfig.defaultEngineId)
                .detectLanguage(detectLanguageRequest);

        _textDetectedLanguage = detectLanguageResponse
            .detections.first.detectedLanguage
            .split('-')[0];

        filteredTranslationTargetList = _translationTargetList
            .where((e) => e.sourceLanguage == _textDetectedLanguage)
            .toList();
      } catch (error) {
        print(error);
      }

      for (var translationTarget in filteredTranslationTargetList) {
        TranslationResult translationResult = TranslationResult(
          translationTarget: translationTarget,
          translationResultRecordList: [],
          unsupportedEngineIdList: [],
        );
        _translationResultList.add(translationResult);
      }

      setState(() {});
    }

    for (int i = 0; i < _translationResultList.length; i++) {
      TranslationTarget translationTarget =
          _translationResultList[i].translationTarget;

      List<String> engineIdList = [];
      List<String> unsupportedEngineIdList = [];

      for (int j = 0; j < _translationEngineList.length; j++) {
        String identifier = _translationEngineList[j].identifier;

        if (_translationEngineList[j].disabled) continue;

        try {
          List<LanguagePair> supportedLanguagePairList = [];
          supportedLanguagePairList = await sharedTranslateClient
              .use(identifier)
              .getSupportedLanguagePairs();

          LanguagePair languagePair = supportedLanguagePairList.firstWhere(
            (e) {
              return e.sourceLanguage == translationTarget.sourceLanguage &&
                  e.targetLanguage == translationTarget.targetLanguage;
            },
            orElse: () => null,
          );
          if (languagePair == null) {
            unsupportedEngineIdList.add(identifier);
          } else {
            engineIdList.add(identifier);
          }
        } catch (error) {
          engineIdList.add(identifier);
        }
      }

      _translationResultList[i].unsupportedEngineIdList =
          unsupportedEngineIdList;

      for (int j = 0; j < engineIdList.length; j++) {
        String identifier = engineIdList[j];

        TranslationResultRecord translationResultRecord =
            TranslationResultRecord(
          id: Uuid().v4(),
          translationEngineId: identifier,
          translationTargetId: translationTarget.id,
        );
        _translationResultList[i]
            .translationResultRecordList
            .add(translationResultRecord);

        Future<bool> future = Future<bool>.sync(() async {
          LookUpRequest lookUpRequest;
          LookUpResponse lookUpResponse;
          UniTranslateClientError lookUpError;
          if (sharedTranslateClient
              .use(identifier)
              .supportedScopes
              .contains(kScopeLookUp)) {
            try {
              lookUpRequest = LookUpRequest(
                sourceLanguage: translationTarget.sourceLanguage,
                targetLanguage: translationTarget.targetLanguage,
                word: _text,
              );
              lookUpResponse = await sharedTranslateClient
                  .use(identifier)
                  .lookUp(lookUpRequest);
            } catch (error) {
              print(error);
              lookUpError = error;
            }
          }

          TranslateRequest translateRequest;
          TranslateResponse translateResponse;
          UniTranslateClientError translateError;
          if (sharedTranslateClient
              .use(identifier)
              .supportedScopes
              .contains(kScopeTranslate)) {
            try {
              translateRequest = TranslateRequest(
                sourceLanguage: translationTarget.sourceLanguage,
                targetLanguage: translationTarget.targetLanguage,
                text: _text,
              );
              translateResponse = await sharedTranslateClient
                  .use(identifier)
                  .translate(translateRequest);
            } catch (error) {
              print(error);
              translateError = error;
            }
          }

          if (lookUpResponse != null) {
            _translationResultList[i]
                .translationResultRecordList[j]
                .lookUpRequest = lookUpRequest;
            _translationResultList[i]
                .translationResultRecordList[j]
                .lookUpResponse = lookUpResponse;
          }
          if (lookUpError != null) {
            _translationResultList[i]
                .translationResultRecordList[j]
                .lookUpError = lookUpError;
          }

          if (translateResponse != null) {
            _translationResultList[i]
                .translationResultRecordList[j]
                .translateRequest = translateRequest;
            _translationResultList[i]
                .translationResultRecordList[j]
                .translateResponse = translateResponse;
          }
          if (translateError != null) {
            _translationResultList[i]
                .translationResultRecordList[j]
                .translateError = translateError;
          }

          setState(() {});

          return true;
        });
        _futureList.add(future);
      }
    }

    await Future.wait(_futureList);
  }

  void _handleTextChanged(
    String newValue, {
    bool isRequery = false,
  }) {
    setState(() {
      _text = newValue;
    });
    if (isRequery) {
      _textEditingController.text = _text;
      _textEditingController.selection = TextSelection(
        baseOffset: _text.length,
        extentOffset: _text.length,
      );
      _queryData();
    }
  }

  void _handleExtractTextFromScreenSelection() async {
    ExtractedData extractedData = await screenTextExtractor.extract(
      mode: ExtractMode.screenSelection,
    );

    await _windowShow();
    await Future.delayed(Duration(milliseconds: 200));
    _handleTextChanged(extractedData.text, isRequery: true);
  }

  void _handleExtractTextFromScreenCapture() async {
    setState(() {
      _querySubmitted = false;
      _text = '';
      _textDetectedLanguage = null;
      _extractedData = null;
      _translationResultList = [];
    });
    _textEditingController.clear();
    _focusNode.unfocus();

    String imagePath;
    if (!kIsWeb) {
      Directory appDir = await sharedConfig.getAppDirectory();
      String fileName =
          'Screenshot-${DateTime.now().millisecondsSinceEpoch}.png';
      imagePath = '${appDir.path}/Screenshots/$fileName';
    }
    ExtractedData extractedData = await screenTextExtractor.extract(
      mode: ExtractMode.screenCapture,
      imagePath: imagePath,
    );

    await _windowShow();
    await Future.delayed(Duration(milliseconds: 200));
    if (extractedData.text == null) {
      _extractedData = extractedData;
      setState(() {});
      DetectTextResponse detectTextResponse =
          await sharedOcrClient.use(sharedConfig.defaultOcrEngineId).detectText(
                DetectTextRequest(
                  imagePath: extractedData.imagePath,
                  base64Image: extractedData.base64Image,
                ),
              );
      _extractedData.text = detectTextResponse.text;
      _handleTextChanged(detectTextResponse.text, isRequery: true);
    } else {
      _handleTextChanged(extractedData.text, isRequery: true);
    }
  }

  void _handleExtractTextFromClipboard() async {
    ExtractedData extractedData = await screenTextExtractor.extract(
      mode: ExtractMode.clipboard,
    );
    _handleTextChanged(extractedData.text, isRequery: true);
  }

  void _handleButtonTappedClear() {
    setState(() {
      _querySubmitted = false;
      _text = '';
      _textDetectedLanguage = null;
      _extractedData = null;
      _translationResultList = [];
    });
    _textEditingController.clear();
    _focusNode.requestFocus();
  }

  void _handleButtonTappedTrans() {
    if (_text.isEmpty) {
      BotToast.showText(
        text: '请输入要翻译的单词或文字',
        align: Alignment.center,
      );
      _focusNode.requestFocus();
      return;
    }
    _queryData();
  }

  Widget _buildBannersView(BuildContext context) {
    bool isFoundNewVersion = _latestVersion != null &&
        _latestVersion.buildNumber >
            int.parse(_packageInfo?.buildNumber?.isEmpty == true
                ? '9999'
                : _packageInfo?.buildNumber);

    bool isNoAllowedAllAccess =
        !(_isAllowedScreenCaptureAccess && _isAllowedScreenSelectionAccess);

    return Container(
      key: _bannersViewKey,
      width: double.infinity,
      margin: EdgeInsets.only(
        bottom: (isFoundNewVersion || isNoAllowedAllAccess) ? 12 : 0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFoundNewVersion)
            NewVersionFoundBanner(
              latestVersion: _latestVersion,
            ),
          if (isNoAllowedAllAccess)
            LimitedFunctionalityBanner(
              isAllowedScreenCaptureAccess: _isAllowedScreenCaptureAccess,
              isAllowedScreenSelectionAccess: _isAllowedScreenSelectionAccess,
              onTappedRecheckIsAllowedAllAccess: () async {
                _isAllowedScreenCaptureAccess =
                    await screenTextExtractor.isAllowedScreenCaptureAccess();
                _isAllowedScreenSelectionAccess =
                    await screenTextExtractor.isAllowedScreenSelectionAccess();

                setState(() {});

                if (_isAllowedScreenCaptureAccess &&
                    _isAllowedScreenSelectionAccess) {
                  BotToast.showText(
                    text:
                        "page_home.limited_banner_msg_all_access_allowed".tr(),
                    align: Alignment.center,
                  );
                } else {
                  BotToast.showText(
                    text: "page_home.limited_banner_msg_all_access_not_allowed"
                        .tr(),
                    align: Alignment.center,
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInputView(BuildContext context) {
    return Container(
      key: _inputViewKey,
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TranslationInputView(
            focusNode: _focusNode,
            controller: _textEditingController,
            onChanged: (newValue) => this._handleTextChanged(newValue),
            extractedData: _extractedData,
            translationMode: _config.translationMode,
            onTranslationModeChanged: (newTranslationMode) {
              sharedConfigManager.setTranslationMode(newTranslationMode);
              setState(() {});
            },
            inputSetting: _config.inputSetting,
            onClickExtractTextFromScreenCapture:
                this._handleExtractTextFromScreenCapture,
            onClickExtractTextFromClipboard:
                this._handleExtractTextFromClipboard,
            onButtonTappedClear: this._handleButtonTappedClear,
            onButtonTappedTrans: this._handleButtonTappedTrans,
          ),
          TranslationTargetSelectView(
            translationMode: _config.translationMode,
            isShowSourceLanguageSelector: _isShowSourceLanguageSelector,
            isShowTargetLanguageSelector: _isShowTargetLanguageSelector,
            onToggleShowSourceLanguageSelector: (newValue) {
              setState(() {
                _isShowSourceLanguageSelector = newValue;
                _isShowTargetLanguageSelector = false;
              });
            },
            onToggleShowTargetLanguageSelector: (newValue) {
              setState(() {
                _isShowSourceLanguageSelector = false;
                _isShowTargetLanguageSelector = newValue;
              });
            },
            sourceLanguage: _sourceLanguage,
            targetLanguage: _targetLanguage,
            onChanged: (newSourceLanguage, newTargetLanguage) {
              setState(() {
                _isShowSourceLanguageSelector = false;
                _isShowTargetLanguageSelector = false;
                _sourceLanguage = newSourceLanguage;
                _targetLanguage = newTargetLanguage;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(BuildContext context) {
    return TranslationResultsView(
      viewKey: _resultsViewKey,
      controller: _scrollController,
      translationMode: _config.translationMode,
      querySubmitted: _querySubmitted,
      text: _text,
      textDetectedLanguage: _textDetectedLanguage,
      translationResultList: _translationResultList,
      onTextTapped: (word) {
        _handleTextChanged(word, isRequery: true);
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    return Container(
      height: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          _buildBannersView(context),
          _buildInputView(context),
          _buildResultsView(context),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return PreferredSize(
      child: Container(
        padding: EdgeInsets.only(left: 8, right: 8, top: 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ToolbarItemAlwaysOnTop(),
            Expanded(child: Container()),
            ToolbarItemSponsor(),
            ToolbarItemSettings(
              onSettingsPageDismiss: () {
                setState(() {});
              },
            ),
          ],
        ),
      ),
      preferredSize: Size.fromHeight(34),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _resizeWindow());
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(context),
    );
  }

  @override
  void onUriSchemeLaunch(Uri uri) async {
    if (uri.scheme != 'biyiapp') return;

    await _windowShow();
    await Future.delayed(Duration(milliseconds: 200));
    if (uri.authority == 'translate') {
      if (_text.isNotEmpty) _handleButtonTappedClear();
      String text = uri.queryParameters['text'];
      if (text != null && text.isNotEmpty) {
        _handleTextChanged(text, isRequery: true);
      }
    }
  }

  @override
  void onTrayIconMouseUp() async {
    _windowShow();
  }

  @override
  void onTrayIconRightMouseUp() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.identifier) {
      case kMenuItemIdShowOrHideMainWindow:
        _windowShow();
        break;
      case kMenuItemIdExitApp:
        windowManager.terminate();
        break;
    }
  }

  @override
  void onWindowFocus() async {
    _focusNode.requestFocus();
  }

  @override
  void onWindowBlur() async {
    _focusNode.unfocus();
    bool isAlwaysOnTop = await windowManager.isAlwaysOnTop();
    if (!isAlwaysOnTop) {
      windowManager.hide();
    }
  }
}