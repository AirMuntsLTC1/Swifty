import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_twitter_clone/ui/theme/theme.dart';
import 'package:flutter_twitter_clone/widgets/brand/swifly_brand.dart';
import 'package:flutter_twitter_clone/widgets/customWidgets.dart';

/// The row under the compose box: image, camera, list icons and the counter.
class ComposeBottomIconWidget extends StatefulWidget {
  final TextEditingController textEditingController;
  final Function(File) onImageIconSelected;
  final VoidCallback onListIconPressed;

  const ComposeBottomIconWidget({
    Key? key,
    required this.textEditingController,
    required this.onImageIconSelected,
    required this.onListIconPressed,
  }) : super(key: key);

  @override
  _ComposeBottomIconWidgetState createState() =>
      _ComposeBottomIconWidgetState();
}

class _ComposeBottomIconWidgetState extends State<ComposeBottomIconWidget> {
  late Color wordCountColor;
  String tweet = '';

  @override
  void initState() {
    wordCountColor = Colors.blue;
    widget.textEditingController.addListener(updateUI);
    super.initState();
  }

  @override
  void dispose() {
    widget.textEditingController.removeListener(updateUI);
    super.dispose();
  }

  void updateUI() {
    setState(() {
      tweet = widget.textEditingController.text;
      if (tweet.isNotEmpty) {
        if (tweet.length > 259 && tweet.length < 280) {
          wordCountColor = Colors.orange;
        } else if (tweet.length >= 280) {
          wordCountColor = Theme.of(context).colorScheme.error;
        } else {
          wordCountColor = Colors.blue;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => setImage(ImageSource.gallery),
            icon: customIcon(context,
                icon: AppIcon.image,
                isTwitterIcon: false,
                iconColor: AppColor.primary),
          ),
          IconButton(
            onPressed: () => setImage(ImageSource.camera),
            icon: customIcon(context,
                icon: AppIcon.camera,
                isTwitterIcon: false,
                iconColor: AppColor.primary),
          ),
          IconButton(
            tooltip: 'Lists',
            onPressed: widget.onListIconPressed,
            icon: customIcon(context,
                icon: AppIcon.lists,
                isTwitterIcon: false,
                iconColor: AppColor.primary),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
                child: tweet.length > 289
                    ? Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: customText(
                          '${280 - tweet.length}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          CircularProgressIndicator(
                            color: SwiflyBrand.blue,
                            value: getTweetLimit(),
                            backgroundColor: Colors.grey,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(wordCountColor),
                          ),
                          tweet.length > 259
                              ? customText('${280 - tweet.length}',
                                  style: TextStyle(color: wordCountColor))
                              : customText('',
                                  style: TextStyle(color: wordCountColor)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void setImage(ImageSource source) {
    ImagePicker()
        .pickImage(source: source, imageQuality: 20)
        .then((XFile? file) {
      if (file == null) return;
      widget.onImageIconSelected(File(file.path));
    });
  }

  double getTweetLimit() {
    if (tweet.isEmpty) return 0.0;
    if (tweet.length > 280) return 1.0;
    return tweet.length / 280;
  }
}
