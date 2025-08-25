import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'onboarding_model.dart';
export 'onboarding_model.dart';

class OnboardingWidget extends StatefulWidget {
  const OnboardingWidget({super.key});

  @override
  State<OnboardingWidget> createState() => _OnboardingWidgetState();
}

class _OnboardingWidgetState extends State<OnboardingWidget> {
  late OnboardingModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OnboardingModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 0.0),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(0.0),
                    bottomRight: Radius.circular(0.0),
                    topLeft: Radius.circular(50.0),
                    topRight: Radius.circular(50.0),
                  ),
                  child: Image.asset(
                    'assets/images/man.jpg',
                    height: 235.0,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(0.0, 5.0, 0.0, 0.0),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(50.0),
                    bottomRight: Radius.circular(50.0),
                    topLeft: Radius.circular(0.0),
                    topRight: Radius.circular(0.0),
                  ),
                  child: Image.asset(
                    'assets/images/Sans-titre-12-5.jpg',
                    height: 200.0,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.asset(
                  'assets/images/grey.png',
                  height: 110.0,
                  fit: BoxFit.contain,
                ),
              ),
              Text(
                'BreatheEasy\nYour Health Companion',
                style: FlutterFlowTheme.of(context).headlineLarge.override(
                      fontFamily: 'Inter Tight',
                      letterSpacing: 0.0,
                    ),
              ),
              Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(12.0, 4.0, 12.0, 0.0),
                child: Text(
                  'Monitor your breathing, sleep, and health insights effortlessly.',
                  style: FlutterFlowTheme.of(context).labelLarge.override(
                        fontFamily: 'Inter',
                        letterSpacing: 0.0,
                      ),
                ),
              ),
              Align(
                alignment: const AlignmentDirectional(0.0, 0.0),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Wrap(
                    spacing: 16.0,
                    runSpacing: 16.0,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    direction: Axis.horizontal,
                    runAlignment: WrapAlignment.start,
                    verticalDirection: VerticalDirection.down,
                    clipBehavior: Clip.none,
                    children: [
                      FFButtonWidget(
                        onPressed: () async {
                          context.pushNamed('Login');
                        },
                        text: 'Login',
                        options: FFButtonOptions(
                          width: 150.0,
                          height: 50.0,
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 0.0),
                          iconPadding: const EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 0.0),
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          textStyle: FlutterFlowTheme.of(context)
                              .titleSmall
                              .override(
                                fontFamily: 'Inter Tight',
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                              ),
                          elevation: 2.0,
                          borderSide: const BorderSide(
                            color: Colors.transparent,
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(50.0),
                        ),
                      ),
                      FFButtonWidget(
                        onPressed: () async {
                          context.pushNamed('CreateAccount');
                        },
                        text: 'Register',
                        options: FFButtonOptions(
                          width: 150.0,
                          height: 50.0,
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 0.0),
                          iconPadding: const EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 0.0),
                          color: FlutterFlowTheme.of(context).primary,
                          textStyle:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    fontFamily: 'Inter Tight',
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    letterSpacing: 0.0,
                                  ),
                          elevation: 2.0,
                          borderSide: const BorderSide(
                            color: Colors.transparent,
                            width: 1.0,
                          ),
                          borderRadius: BorderRadius.circular(40.0),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
