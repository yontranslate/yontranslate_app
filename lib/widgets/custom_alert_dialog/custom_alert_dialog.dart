import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../includes.dart';

const kDialogActionTypePrimary = 'primary';
const kDialogActionTypeSecondary = 'secondary';
const kDialogActionTypeSuccess = 'success';
const kDialogActionTypeDanger = 'danger';

class CustomDialogAction extends StatelessWidget {
  String type;
  final bool processing;
  final Widget child;
  final VoidCallback onPressed;

  CustomDialogAction({
    Key key,
    this.type,
    this.processing = false,
    @required this.child,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      child: CustomButton.filled(
        padding: EdgeInsets.zero,
        processing: processing,
        child: this.child,
        onPressed: this.onPressed,
      ),
    );
  }
}

class CustomAlertDialog extends StatelessWidget {
  final Widget title;
  final Widget content;
  final List<Widget> actions;

  const CustomAlertDialog({
    Key key,
    this.title,
    this.content,
    this.actions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double minHeight = this.content == null ? 140 : 172;
    return Container(
      alignment: Alignment.center,
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          color: Color(0xff262626),
          fontSize: 14,
        ),
        child: Container(
          constraints: BoxConstraints(
            minHeight: minHeight,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          margin: EdgeInsets.only(left: 40, right: 40),
          padding: EdgeInsets.only(top: 20, bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(left: 20, right: 20),
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: Color(0xff262626),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  child: this.title ?? Container(),
                ),
              ),
              if (this.content != null)
                Padding(
                  padding: EdgeInsets.only(
                    left: 30,
                    right: 30,
                    top: 18,
                    bottom: 30,
                  ),
                  child: this.content,
                ),
              Container(
                padding: EdgeInsets.only(left: 20, right: 20),
                child: Row(
                  children: <Widget>[
                    for (var i = 0; i < this.actions.length; i++)
                      Builder(
                        builder: (_) {
                          CustomDialogAction action = this.actions[i];
                          if (action.type == null &&
                              i == this.actions.length - 1) {
                            action.type = kDialogActionTypePrimary;
                          }
                          return Expanded(
                            child: Container(
                              padding: EdgeInsets.only(left: 5, right: 5),
                              child: action,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}