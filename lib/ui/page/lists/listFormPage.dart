import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flutter_twitter_clone/helper/customRoute.dart';
import 'package:flutter_twitter_clone/model/swifly_list.dart';
import 'package:flutter_twitter_clone/supabase/supabase_lists_repository.dart';
import 'package:flutter_twitter_clone/ui/page/lists/list_common.dart';
import 'package:flutter_twitter_clone/ui/page/profile/widgets/circular_image.dart';
import 'package:flutter_twitter_clone/ui/theme/theme.dart';

/// Create a list (no [list]) or edit one. Pops with true when saved.
class ListFormPage extends StatefulWidget {
  const ListFormPage({super.key, this.list});

  final SwiflyList? list;

  static Route<bool> getRoute({SwiflyList? list}) {
    return CustomRoute<bool>(
      builder: (_) => ListFormPage(list: list),
      settings: const RouteSettings(name: 'ListFormPage'),
    );
  }

  @override
  State<ListFormPage> createState() => _ListFormPageState();
}

class _ListFormPageState extends State<ListFormPage> {
  final _repo = SwiflyListsRepository.instance;
  late final TextEditingController _name =
      TextEditingController(text: widget.list?.name ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.list?.description ?? '');
  late String _icon = widget.list?.icon ?? 'list';
  late bool _isPrivate = widget.list?.isPrivate ?? false;
  File? _pickedCover;
  bool _removeCover = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.list != null;

  ImageProvider? get _coverImage {
    if (_pickedCover != null) return FileImage(_pickedCover!);
    final existing = widget.list?.coverUrl;
    if (!_removeCover && existing != null) {
      return customAdvanceNetworkImage(existing);
    }
    return null;
  }

  Future<void> _pickCover() async {
    final file = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (file == null || !mounted) return;
    setState(() {
      _pickedCover = File(file.path);
      _removeCover = false;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Give your list a name');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // The cover: a newly picked photo is uploaded; removing clears it;
      // otherwise the existing cover stays as it is.
      String coverValue;
      if (_pickedCover != null) {
        coverValue = await _repo.uploadCover(_pickedCover!);
      } else if (_removeCover) {
        coverValue = '';
      } else {
        coverValue = widget.list?.coverUrl ?? '';
      }

      if (_isEdit) {
        await _repo.updateList(
          widget.list!.id,
          name: name,
          description: _description.text.trim(),
          icon: _icon,
          coverUrl: coverValue,
          isPrivate: _isPrivate,
        );
      } else {
        await _repo.createList(
          name: name,
          description: _description.text.trim(),
          icon: _icon,
          coverUrl: coverValue,
          isPrivate: _isPrivate,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      // The repository has already shown the error.
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _coverImage;
    return Scaffold(
      backgroundColor: TwitterColor.mystic,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(_isEdit ? 'Edit list' : 'New list',
            style: listTitleStyle(size: 18)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.6),
          child: Container(height: 0.6, color: kListDividerColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
        children: [
          GestureDetector(
            onTap: _pickCover,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: image == null
                    ? LinearGradient(
                        colors: widget.list?.gradient ?? kListGradients[0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                image: image == null
                    ? null
                    : DecorationImage(image: image, fit: BoxFit.cover),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt_outlined,
                            color: Colors.white, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          image == null ? 'Add cover photo' : 'Change cover photo',
                          style: listTitleStyle(size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  if (image != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          tooltip: 'Remove cover',
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => setState(() {
                            _pickedCover = null;
                            _removeCover = true;
                          }),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _card(
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  maxLength: 40,
                  style: listTitleStyle(size: 16),
                  decoration: _fieldDecoration('Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _description,
                  maxLength: 160,
                  maxLines: 3,
                  decoration: _fieldDecoration('Description (optional)'),
                ),
              ],
            ),
          ),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Icon', style: listTitleStyle(size: 15)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in SwiflyListIcons.byKey.entries)
                      _iconChoice(entry.key, entry.value),
                  ],
                ),
              ],
            ),
          ),
          _card(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColor.primary,
              value: _isPrivate,
              onChanged: (v) => setState(() => _isPrivate = v),
              title: Text('Private list', style: listTitleStyle(size: 16)),
              subtitle: Text(
                _isPrivate
                    ? 'Only you and your collaborators can see this list.'
                    : 'Anyone can find this list and follow it.',
                style: listGreyStyle(size: 13, weight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.primary,
                disabledBackgroundColor: AppColor.primary.withValues(alpha: 0.5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEdit ? 'Save changes' : 'Create list',
                      style: listTitleStyle(size: 16, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _iconChoice(String key, IconData icon) {
    final selected = _icon == key;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => setState(() => _icon = key),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? AppColor.primary : TwitterColor.mystic,
        ),
        child: Icon(
          icon,
          color: selected ? Colors.white : AppColor.darkGrey,
          size: 22,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: listGreyStyle(size: 14),
      floatingLabelStyle: listGreyStyle(size: 14),
      filled: true,
      fillColor: const Color(0xffF5F8FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColor.primary, width: 1.5),
      ),
    );
  }
}
