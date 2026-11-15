import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:flutter_twitter_clone/helper/customRoute.dart';
import 'package:flutter_twitter_clone/helper/user_location.dart';
import 'package:flutter_twitter_clone/helper/utility.dart';
import 'package:flutter_twitter_clone/state/authState.dart';
import 'package:flutter_twitter_clone/widgets/cache_image.dart';
import 'package:flutter_twitter_clone/widgets/customFlatButton.dart';
import 'package:flutter_twitter_clone/widgets/customWidgets.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  static MaterialPageRoute<T> getRoute<T>() {
    return CustomRoute<T>(
        builder: (BuildContext context) => const EditProfilePage());
  }

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  File? _image;
  File? _banner;
  late TextEditingController _name;
  late TextEditingController _bio;
  late TextEditingController _location;
  late TextEditingController _dob;

  /// Date of birth as yyyy-MM-dd, set only when the user picks a new date.
  String? dob;
  bool _saving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthState>(context, listen: false).userModel;
    _name = TextEditingController(text: user?.displayName ?? '');
    _bio = TextEditingController(text: user?.bio ?? '');
    _location = TextEditingController(text: user?.location ?? '');
    _dob = TextEditingController(text: Utility.getDob(user?.dob));
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _location.dispose();
    _dob.dispose();
    super.dispose();
  }

  Widget _body() {
    final authState = Provider.of<AuthState>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 180,
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: _bannerImage(authState)),
              Align(
                alignment: Alignment.bottomLeft,
                child: _userImage(authState),
              ),
            ],
          ),
        ),
        _entry('Name', controller: _name),
        _entry('Bio', controller: _bio, maxLine: 3),
        _entry('Location',
            controller: _location,
            onTap: () => _fillLocation(),
            suffix: _locateButton()),
        InkWell(
          onTap: showCalender,
          child: _entry('Date of birth', enabled: false, controller: _dob),
        ),
      ],
    );
  }

  Widget _userImage(AuthState authState) {
    final avatar = authState.userModel?.profilePic;
    return Container(
      height: 90,
      width: 90,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(5),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _image != null
                ? Image.file(_image!, fit: BoxFit.cover)
                : CacheImage(path: avatar, fit: BoxFit.cover),
            Container(
              color: Colors.black38,
              child: Center(
                child: IconButton(
                  onPressed: uploadImage,
                  icon: const Icon(LucideIcons.camera, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bannerImage(AuthState authState) {
    final cover = authState.userModel?.bannerImage;
    Widget background;
    if (_banner != null) {
      background = Image.file(_banner!, fit: BoxFit.cover);
    } else if (cover != null && cover.isNotEmpty) {
      background = CacheImage(path: cover, fit: BoxFit.cover);
    } else {
      background = Container(color: Colors.grey.shade400);
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        background,
        Container(color: Colors.black26),
        Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: Colors.black38,
            ),
            child: IconButton(
              onPressed: uploadBanner,
              icon: const Icon(LucideIcons.camera, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _entry(String title,
      {required TextEditingController controller,
      int maxLine = 1,
      bool enabled = true,
      VoidCallback? onTap,
      Widget? suffix}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          customText(title, style: const TextStyle(color: Colors.black54)),
          TextField(
            enabled: enabled,
            controller: controller,
            maxLines: maxLine,
            onTap: onTap,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
              suffixIcon: suffix,
            ),
          )
        ],
      ),
    );
  }

  /// Fills the location with the user's place. Asks for permission first when
  /// needed. Tapping the field fills it only when it is empty.
  Future<void> _fillLocation({bool force = false}) async {
    if (_locating) return;
    if (!force && _location.text.trim().isNotEmpty) return;
    setState(() => _locating = true);
    try {
      final place = await currentPlaceName();
      if (!mounted) return;
      setState(() => _location.text = place);
    } on LocationException catch (error) {
      if (mounted) Utility.customSnackBar(context, error.message);
    } catch (_) {
      if (mounted) {
        Utility.customSnackBar(context, 'Could not get your location.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Widget _locateButton() {
    return _locating
        ? const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : IconButton(
            tooltip: 'Use my location',
            icon: const Icon(LucideIcons.mapPin, color: Colors.blue),
            onPressed: () => _fillLocation(force: true),
          );
  }

  Future<void> showCalender() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      dob = '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      _dob.text = DateFormat.yMMMd().format(picked);
    });
  }

  Future<void> _submitButton() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      Utility.customSnackBar(context, 'Name cannot be empty');
      return;
    }
    if (name.length > 27) {
      Utility.customSnackBar(context, 'Name length cannot exceed 27 character');
      return;
    }
    final state = Provider.of<AuthState>(context, listen: false);
    final current = state.userModel;
    if (current == null) return;

    final model = current.copyWith(
      displayName: name,
      bio: _bio.text.trim(),
      location: _location.text.trim(),
      dob: dob ?? current.dob,
    );

    setState(() => _saving = true);
    try {
      await state.updateUserProfile(model, image: _image, bannerImage: _banner);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      // The repository already showed the error. Stay on the page to retry.
      if (mounted) setState(() => _saving = false);
    }
  }

  void uploadImage() {
    openImagePicker(context, (file) {
      setState(() {
        _image = file;
      });
    });
  }

  void uploadBanner() {
    openImagePicker(context, (file) {
      setState(() {
        _banner = file;
      });
    });
  }

  void openImagePicker(BuildContext context, Function(File) onImageSelected) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext sheetContext) {
        return Container(
          height: 130,
          padding: const EdgeInsets.all(10),
          child: Column(
            children: <Widget>[
              const Text(
                'Pick an image',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: CustomFlatButton(
                      label: 'Use Camera',
                      borderRadius: 5,
                      onPressed: () => getImage(
                          sheetContext, ImageSource.camera, onImageSelected),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CustomFlatButton(
                      label: 'Use Gallery',
                      borderRadius: 5,
                      onPressed: () => getImage(
                          sheetContext, ImageSource.gallery, onImageSelected),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Picks an image. Cancelling the picker keeps the current photo.
  Future<void> getImage(BuildContext sheetContext, ImageSource source,
      Function(File) onImageSelected) async {
    final XFile? file =
        await ImagePicker().pickImage(source: source, imageQuality: 50);
    if (!mounted) return;
    Navigator.pop(sheetContext);
    if (file != null) {
      onImageSelected(File(file.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.blue),
        title: customTitleText('Profile Edit'),
        actions: <Widget>[
          InkWell(
            onTap: _saving ? null : () => _submitButton(),
            child: Center(
              child: _saving
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: SingleChildScrollView(
        child: _body(),
      ),
    );
  }
}
