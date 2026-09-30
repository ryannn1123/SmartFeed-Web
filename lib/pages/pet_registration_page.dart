
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

// =========================
// SHARED PALETTE
// =========================

class _Palette {
  static const Color salmon = Color(0xFFFA7268);
  static const Color peach = Color(0xFFFF9E89);
  static const Color blush = Color(0xFFFFD6C4);
  static const Color cream = Color(0xFFFFEFC4);
  static const Color brown = Color(0xFF5B3A29);
  static const Color brownSoft = Color(0xFF7A3E2A);
  static const Color muted = Color(0xFFAD8A79);
}

class PetRegistrationPage extends StatefulWidget {
  const PetRegistrationPage({super.key});

  @override
  State<PetRegistrationPage> createState() =>
      _PetRegistrationPageState();
}

class _PetRegistrationPageState extends State<PetRegistrationPage> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  final _supabase = Supabase.instance.client;

  String _petType = 'Dog';
  String _gender = 'Male';

  bool _loading = false;
  bool _fetching = true;

  int? _editingPetId;

  List<Map<String, dynamic>> _pets = [];

  @override
  void initState() {
    super.initState();
    _fetchPets();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  // ============================================================
  // FETCH PETS
  // ============================================================

  Future<void> _fetchPets() async {
    if (!mounted) return;

    setState(() => _fetching = true);

    try {
      final userId = _supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not logged in.');
      }

      final res = await _supabase
          .from('pets')
          .select()
          .eq('owner_id', userId)
          .order('id', ascending: false);

      if (!mounted) return;

      setState(() {
        _pets = List<Map<String, dynamic>>.from(res);
        _fetching = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _fetching = false);
      _showMessage('Error loading pets: $e');
    }
  }

  // ============================================================
  // SHOW REGISTER DIALOG
  // ============================================================

  Future<void> _showRegisterDialog() async {
    _clearForm();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PetFormDialog(
        title: 'Register New Pet',
        buttonText: 'Register Pet',
        nameController: _nameController,
        ageController: _ageController,
        petType: _petType,
        gender: _gender,
        loading: _loading,
        requirePhoto: true,
        onPetTypeChanged: (value) {
          _petType = value;
        },
        onGenderChanged: (value) {
          _gender = value;
        },
        onSubmit: (selectedImages) async {
          final success = await _savePet(selectedImages);

          if (success && mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  // ============================================================
  // SHOW EDIT DIALOG
  // ============================================================

  Future<void> _showEditDialog(
    Map<String, dynamic> pet,
  ) async {
    setState(() {
      _editingPetId = pet['id'] as int;

      _nameController.text =
          pet['pet_name']?.toString() ?? '';

      _petType =
          pet['pet_type']?.toString() ?? 'Dog';

      _ageController.text =
          pet['age']?.toString() ?? '';

      _gender =
          pet['gender']?.toString() ?? 'Male';
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PetFormDialog(
        title: 'Edit Pet',
        buttonText: 'Save Changes',
        nameController: _nameController,
        ageController: _ageController,
        petType: _petType,
        gender: _gender,
        loading: _loading,
        requirePhoto: false,
        onPetTypeChanged: (value) {
          _petType = value;
        },
        onGenderChanged: (value) {
          _gender = value;
        },
        onSubmit: (selectedImages) async {
          final success = await _savePet(selectedImages);

          if (success && mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  // ============================================================
  // SAVE PET
  // ============================================================

  Future<bool> _savePet(
    List<XFile> selectedImages,
  ) async {
    final name = _nameController.text.trim();
    final ageText = _ageController.text.trim();

    if (name.isEmpty || ageText.isEmpty) {
      _showMessage('Please complete all fields.');
      return false;
    }

    final age = int.tryParse(ageText);

    if (age == null || age < 0) {
      _showMessage('Please enter a valid age.');
      return false;
    }

    // New pets require at least one photo.
    if (_editingPetId == null &&
        selectedImages.isEmpty) {
      _showMessage(
        'Please add at least one photo of your pet.',
      );
      return false;
    }

    if (!mounted) return false;

    setState(() => _loading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not logged in.');
      }

      final data = {
        'owner_id': userId,
        'pet_name': name,
        'pet_type': _petType,
        'age': age,
        'gender': _gender,
      };

      // ========================================================
      // REGISTER NEW PET
      // ========================================================

      if (_editingPetId == null) {
        final insertedPet = await _supabase
            .from('pets')
            .insert(data)
            .select('id')
            .single();

        final petId = insertedPet['id'] as int;

        // Upload selected photos.
        final photoPaths = await _uploadPetPhotos(
          petId,
          selectedImages,
        );

        // Save photo paths to database.
        await _supabase
            .from('pets')
            .update({
              'photo_paths': photoPaths,
            })
            .eq('id', petId)
            .eq('owner_id', userId);

        _showMessage(
          'Pet registered with '
          '${photoPaths.length} photo(s) 🐾',
        );
      }

      // ========================================================
      // EDIT EXISTING PET
      // ========================================================

      else {
        await _supabase
            .from('pets')
            .update(data)
            .eq('id', _editingPetId as int)
            .eq('owner_id', userId);

        // Upload new photos if selected.
        if (selectedImages.isNotEmpty) {
          final photoPaths = await _uploadPetPhotos(
            _editingPetId as int,
            selectedImages,
          );

          await _supabase
              .from('pets')
              .update({
                'photo_paths': photoPaths,
              })
              .eq('id', _editingPetId as int)
              .eq('owner_id', userId);

          _showMessage(
            'Pet updated with '
            '${photoPaths.length} photo(s) 🐾',
          );
        } else {
          _showMessage(
            'Pet updated successfully 🐾',
          );
        }
      }

      _clearForm();

      await _fetchPets();

      return true;
    } catch (e) {
      _showMessage('Error: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ============================================================
  // UPLOAD PET PHOTOS
  // ============================================================

  Future<List<String>> _uploadPetPhotos(
    int petId,
    List<XFile> images,
  ) async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId == null) {
      throw Exception('User is not logged in.');
    }

    final uploadedPaths = <String>[];

    for (int i = 0; i < images.length; i++) {
      final image = images[i];

      final Uint8List bytes =
          await image.readAsBytes();

      String extension = 'jpg';

      if (image.name.contains('.')) {
        extension =
            image.name.split('.').last.toLowerCase();

        if (extension == 'jpeg') {
          extension = 'jpg';
        }
      }

      final timestamp =
          DateTime.now().millisecondsSinceEpoch;

      final path =
          '$userId/pet_$petId/'
          '${timestamp}_$i.$extension';

      String contentType = 'image/jpeg';

      if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'webp') {
        contentType = 'image/webp';
      }

      await _supabase.storage
          .from('pet-photos')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      uploadedPaths.add(path);
    }

    return uploadedPaths;
  }

  // ============================================================
  // DELETE PET
  // ============================================================

  Future<void> _deletePet(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFFDF9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Text(
          'Delete pet?',
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.w700,
            color: _Palette.brownSoft,
          ),
        ),
        content: Text(
          'This pet profile will be removed.',
          style: GoogleFonts.dmSans(
            color: _Palette.brownSoft.withOpacity(0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(
                color: _Palette.muted,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () =>
                Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final userId =
          _supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('User is not logged in.');
      }

      // Get photo paths before deleting pet.
      final pet = await _supabase
          .from('pets')
          .select('photo_paths')
          .eq('id', id)
          .eq('owner_id', userId)
          .maybeSingle();

      // Delete photos from Storage.
      if (pet != null) {
        final photoPaths = pet['photo_paths'];

        if (photoPaths is List &&
            photoPaths.isNotEmpty) {
          final paths = photoPaths
              .map((e) => e.toString())
              .toList();

          try {
            await _supabase.storage
                .from('pet-photos')
                .remove(paths);
          } catch (_) {
            // Don't stop deletion if storage cleanup fails.
          }
        }
      }

      // Delete pet record.
      await _supabase
          .from('pets')
          .delete()
          .eq('id', id)
          .eq('owner_id', userId);

      await _fetchPets();

      _showMessage('Pet deleted.');
    } catch (e) {
      _showMessage(
        'Error deleting pet: $e',
      );
    }
  }

  // ============================================================
  // CLEAR FORM
  // ============================================================

  void _clearForm() {
    _editingPetId = null;

    _nameController.clear();
    _ageController.clear();

    _petType = 'Dog';
    _gender = 'Male';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // MAIN UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _Palette.peach,
              Color(0xFFFFBFA3),
              Color(0xFFFFD8A0),
              _Palette.cream,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: _Palette.salmon,
            onRefresh: _fetchPets,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                18,
                16,
                18,
                150,
              ),
              children: [
                // =========================
                // HEADER
                // =========================

                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _Palette.salmon,
                            _Palette.peach,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.pets,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'My Pets',
                      style: GoogleFonts.fraunces(
                        color: _Palette.brownSoft,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // =========================
                // REGISTER BUTTON
                // =========================

                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(22),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _Palette.salmon,
                          _Palette.peach,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _Palette.salmon
                              .withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: FilledButton.icon(
                      onPressed: _showRegisterDialog,
                      icon: const Icon(
                        Icons.pets_rounded,
                      ),
                      label: Text(
                        'Register a Pet',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            Colors.transparent,
                        shadowColor:
                            Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(22),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // =========================
                // PET COUNT
                // =========================

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color:
                        Colors.white.withOpacity(0.9),
                    borderRadius:
                        BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _Palette.brownSoft
                            .withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _Palette.blush
                              .withOpacity(0.6),
                          borderRadius:
                              BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.pets_rounded,
                          color: _Palette.salmon,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_pets.length} Registered Pets',
                        style: GoogleFonts.fraunces(
                          color: _Palette.brown,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                if (_fetching)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        color: _Palette.salmon,
                      ),
                    ),
                  )
                else if (_pets.isEmpty)
                  _emptyState()
                else
                  ..._pets.map(
                    (pet) => _petCard(pet),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: _Palette.blush.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pets_rounded,
              size: 42,
              color: _Palette.salmon,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No pets yet',
            style: GoogleFonts.fraunces(
              color: _Palette.brownSoft,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "Register a Pet" to add your first pet.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: _Palette.brownSoft
                  .withOpacity(0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PET CARD
  // ============================================================

  Widget _petCard(Map<String, dynamic> pet) {
    final id = pet['id'] as int;

    final name =
        pet['pet_name']?.toString() ?? 'Pet';

    final type =
        pet['pet_type']?.toString() ?? 'Pet';

    final age =
        pet['age']?.toString() ?? '0';

    final gender =
        pet['gender']?.toString() ?? '';

    final photoPaths = pet['photo_paths'];

    final hasPhotos =
        photoPaths is List &&
        photoPaths.isNotEmpty;

    String? firstPhotoUrl;

    if (hasPhotos) {
      try {
        firstPhotoUrl = _supabase.storage
            .from('pet-photos')
            .getPublicUrl(
              photoPaths.first.toString(),
            );
      } catch (_) {
        firstPhotoUrl = null;
      }
    }

    return Container(
      margin:
          const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          // =========================
          // PET IMAGE
          // =========================

          Container(
            width: 64,
            height: 64,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _Palette.salmon
                      .withOpacity(0.85),
                  _Palette.peach
                      .withOpacity(0.85),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(18),
            ),
            child: firstPhotoUrl != null
                ? Image.network(
                    firstPhotoUrl,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) {
                      return const Icon(
                        Icons.pets_rounded,
                        color: Colors.white,
                        size: 30,
                      );
                    },
                  )
                : const Icon(
                    Icons.pets_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
          ),

          const SizedBox(width: 14),

          // =========================
          // PET INFORMATION
          // =========================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.fraunces(
                    color: _Palette.brown,
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '$type • $gender • $age yrs',
                  style: GoogleFonts.dmSans(
                    color: _Palette.brownSoft
                        .withOpacity(0.7),
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                if (hasPhotos) ...[
                  const SizedBox(height: 6),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration:
                        BoxDecoration(
                      color: _Palette.cream,
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons
                              .photo_library_rounded,
                          size: 13,
                          color:
                              _Palette.salmon,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${photoPaths.length} photos',
                          style:
                              GoogleFonts.dmSans(
                            color:
                                _Palette.brownSoft,
                            fontSize: 11,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // =========================
          // MENU
          // =========================

          PopupMenuButton<String>(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(16),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditDialog(pet);
              }

              if (value == 'delete') {
                _deletePet(id);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    const Icon(
                      Icons.edit_rounded,
                      size: 18,
                      color:
                          _Palette.salmon,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Edit',
                      style:
                          GoogleFonts.dmSans(),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .delete_outline_rounded,
                      size: 18,
                      color:
                          Colors.redAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Delete',
                      style:
                          GoogleFonts.dmSans(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CARD DECORATION
  // ============================================================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.92),
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: _Palette.brownSoft
              .withOpacity(0.1),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

// ===================================================================
// PET FORM DIALOG
// ===================================================================

class _PetFormDialog extends StatefulWidget {
  final String title;
  final String buttonText;

  final TextEditingController nameController;
  final TextEditingController ageController;

  final String petType;
  final String gender;

  final bool loading;
  final bool requirePhoto;

  final ValueChanged<String>
      onPetTypeChanged;

  final ValueChanged<String>
      onGenderChanged;

  final Future<void> Function(
    List<XFile> selectedImages,
  ) onSubmit;

  const _PetFormDialog({
    required this.title,
    required this.buttonText,
    required this.nameController,
    required this.ageController,
    required this.petType,
    required this.gender,
    required this.loading,
    required this.requirePhoto,
    required this.onPetTypeChanged,
    required this.onGenderChanged,
    required this.onSubmit,
  });

  @override
  State<_PetFormDialog> createState() =>
      _PetFormDialogState();
}

class _PetFormDialogState
    extends State<_PetFormDialog> {
  late String _selectedPetType;
  late String _selectedGender;

  final ImagePicker _picker =
      ImagePicker();

  List<XFile> _selectedImages = [];

  bool _selectingPhotos = false;

  @override
  void initState() {
    super.initState();

    _selectedPetType =
        widget.petType;

    _selectedGender =
        widget.gender;
  }

  // ============================================================
  // PICK PHOTOS
  // ============================================================

  Future<void> _selectPhotos() async {
    if (_selectingPhotos) return;

    setState(() {
      _selectingPhotos = true;
    });

    try {
      final images =
          await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (images.isEmpty) {
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedImages =
            images.take(20).toList();
      });

      if (images.length > 20) {
        _showMessage(
          'Only the first 20 photos were selected.',
        );
      }
    } catch (e) {
      _showMessage(
        'Error selecting photos: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _selectingPhotos = false;
        });
      }
    }
  }

  // ============================================================
  // REMOVE PHOTO
  // ============================================================

  void _removePhoto(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor:
          const Color(0xFFFFFDF9),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(28),
      ),
      title: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration:
                const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _Palette.salmon,
                  _Palette.peach,
                ],
              ),
            ),
            child: const Icon(
              Icons.pets,
              color: Colors.white,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style:
                  GoogleFonts.fraunces(
                color:
                    _Palette.brownSoft,
                fontWeight:
                    FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),

      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              // ==================================================
              // PET NAME
              // ==================================================

              _input(
                controller:
                    widget.nameController,
                label: 'Pet Name',
                icon:
                    Icons.badge_rounded,
              ),

              const SizedBox(height: 14),

              // ==================================================
              // PET TYPE
              // ==================================================

              DropdownButtonFormField<
                  String>(
                value:
                    _selectedPetType,
                style:
                    GoogleFonts.dmSans(
                  color:
                      _Palette.brown,
                  fontSize: 15,
                ),
                decoration:
                    _inputDecoration(
                  label: 'Pet Type',
                  icon:
                      Icons.pets_rounded,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Dog',
                    child:
                        Text('🐶 Dog'),
                  ),
                  DropdownMenuItem(
                    value: 'Cat',
                    child:
                        Text('🐱 Cat'),
                  ),
                  DropdownMenuItem(
                    value: 'Bird',
                    child:
                        Text('🐦 Bird'),
                  ),
                  DropdownMenuItem(
                    value: 'Rabbit',
                    child:
                        Text('🐰 Rabbit'),
                  ),
                  DropdownMenuItem(
                    value: 'Other',
                    child:
                        Text('🐾 Other'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedPetType =
                        value;
                  });

                  widget
                      .onPetTypeChanged(
                    value,
                  );
                },
              ),

              const SizedBox(height: 14),

              // ==================================================
              // AGE
              // ==================================================

              _input(
                controller:
                    widget.ageController,
                label: 'Age',
                icon:
                    Icons.cake_rounded,
                keyboardType:
                    TextInputType.number,
              ),

              const SizedBox(height: 14),

              // ==================================================
              // GENDER
              // ==================================================

              DropdownButtonFormField<
                  String>(
                value:
                    _selectedGender,
                style:
                    GoogleFonts.dmSans(
                  color:
                      _Palette.brown,
                  fontSize: 15,
                ),
                decoration:
                    _inputDecoration(
                  label: 'Gender',
                  icon:
                      Icons.pets_rounded,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Male',
                    child: Text(
                      '♂ Male',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Female',
                    child: Text(
                      '♀ Female',
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedGender =
                        value;
                  });

                  widget
                      .onGenderChanged(
                    value,
                  );
                },
              ),

              const SizedBox(height: 20),

              // ==================================================
              // PHOTO SECTION
              // ==================================================

              Align(
                alignment:
                    Alignment.centerLeft,
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .photo_library_rounded,
                      color:
                          _Palette.salmon,
                      size: 20,
                    ),
                    const SizedBox(
                      width: 7,
                    ),
                    Text(
                      'Pet Photos',
                      style:
                          GoogleFonts.dmSans(
                        color:
                            _Palette.brown,
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 7),

              Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  'Add clear photos of the same pet from different angles for better AI recognition.',
                  style:
                      GoogleFonts.dmSans(
                    color:
                        _Palette.muted,
                    fontSize: 12,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // ADD PHOTOS BUTTON
              // ==================================================

              InkWell(
                onTap: widget.loading ||
                        _selectingPhotos
                    ? null
                    : _selectPhotos,
                borderRadius:
                    BorderRadius.circular(
                        18),
                child: Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 18,
                    horizontal: 14,
                  ),
                  decoration:
                      BoxDecoration(
                    color: _Palette
                        .blush
                        .withOpacity(
                            0.3),
                    borderRadius:
                        BorderRadius
                            .circular(18),
                    border:
                        Border.all(
                      color: _Palette
                          .salmon
                          .withOpacity(
                              0.35),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (_selectingPhotos)
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child:
                              CircularProgressIndicator(
                            color:
                                _Palette
                                    .salmon,
                            strokeWidth:
                                2.5,
                          ),
                        )
                      else
                        const Icon(
                          Icons
                              .add_a_photo_rounded,
                          color:
                              _Palette
                                  .salmon,
                          size: 34,
                        ),

                      const SizedBox(
                          height: 8),

                      Text(
                        _selectedImages
                                .isEmpty
                            ? 'Add Photos'
                            : 'Change Photos',
                        style:
                            GoogleFonts
                                .dmSans(
                          color:
                              _Palette
                                  .brown,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),

                      const SizedBox(
                          height: 3),

                      Text(
                        _selectedImages
                                .isEmpty
                            ? 'Select up to 20 photos'
                            : '${_selectedImages.length} photos selected',
                        style:
                            GoogleFonts
                                .dmSans(
                          color:
                              _Palette
                                  .muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ==================================================
              // PHOTO PREVIEW
              // ==================================================

              if (_selectedImages
                  .isNotEmpty) ...[
                const SizedBox(
                    height: 14),

                SizedBox(
                  height: 100,
                  child:
                      ListView.builder(
                    scrollDirection:
                        Axis.horizontal,
                    itemCount:
                        _selectedImages
                            .length,
                    itemBuilder:
                        (context,
                            index) {
                      return FutureBuilder<
                          Uint8List>(
                        future:
                            _selectedImages[
                                    index]
                                .readAsBytes(),
                        builder:
                            (context,
                                snapshot) {
                          return Container(
                            width: 90,
                            height: 90,
                            margin:
                                const EdgeInsets
                                    .only(
                              right: 10,
                            ),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                              16),
                                  child: snapshot
                                          .hasData
                                      ? Image.memory(
                                          snapshot
                                              .data!,
                                          width:
                                              90,
                                          height:
                                              90,
                                          fit: BoxFit
                                              .cover,
                                        )
                                      : Container(
                                          width:
                                              90,
                                          height:
                                              90,
                                          color: _Palette
                                              .blush
                                              .withOpacity(
                                                  0.4),
                                          child:
                                              const Center(
                                            child:
                                                CircularProgressIndicator(
                                              color:
                                                  _Palette.salmon,
                                              strokeWidth:
                                                  2,
                                            ),
                                          ),
                                        ),
                                ),

                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child:
                                      GestureDetector(
                                    onTap: () =>
                                        _removePhoto(
                                            index),
                                    child:
                                        Container(
                                      width:
                                          25,
                                      height:
                                          25,
                                      decoration:
                                          const BoxDecoration(
                                        color:
                                            Colors.redAccent,
                                        shape:
                                            BoxShape.circle,
                                      ),
                                      child:
                                          const Icon(
                                        Icons
                                            .close,
                                        color:
                                            Colors.white,
                                        size:
                                            16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],

              if (widget.requirePhoto &&
                  _selectedImages.isEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    '* At least one pet photo is required.',
                    style:
                        GoogleFonts.dmSans(
                      color:
                          Colors.redAccent,
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),

      // ========================================================
      // ACTION BUTTONS
      // ========================================================

      actionsPadding:
          const EdgeInsets.fromLTRB(
        18,
        0,
        18,
        18,
      ),

      actions: [
        TextButton(
          onPressed: widget.loading
              ? null
              : () =>
                  Navigator.pop(context),
          child: Text(
            'Cancel',
            style:
                GoogleFonts.dmSans(
              color:
                  _Palette.muted,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),

        DecoratedBox(
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
                    14),
            gradient:
                const LinearGradient(
              colors: [
                _Palette.salmon,
                _Palette.peach,
              ],
            ),
          ),
          child:
              FilledButton.icon(
            onPressed:
                widget.loading ||
                        _selectingPhotos
                    ? null
                    : () async {
                        await widget
                            .onSubmit(
                          _selectedImages,
                        );
                      },
            icon: widget.loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(
                      color:
                          Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons
                        .pets_rounded,
                  ),
            label: Text(
              widget.buttonText,
              style:
                  GoogleFonts.dmSans(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            style:
                FilledButton.styleFrom(
              backgroundColor:
                  Colors.transparent,
              shadowColor:
                  Colors.transparent,
              foregroundColor:
                  Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                        14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _input({
    required TextEditingController
        controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType =
        TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.dmSans(
        color: _Palette.brown,
        fontSize: 15,
      ),
      decoration:
          _inputDecoration(
        label: label,
        icon: icon,
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          GoogleFonts.dmSans(
        color: _Palette.muted,
      ),
      prefixIcon: Icon(
        icon,
        color: _Palette.salmon,
      ),
      filled: true,
      fillColor: Colors.white,
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(18),
        borderSide:
            const BorderSide(
          color: _Palette.salmon,
          width: 1.5,
        ),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(18),
        borderSide: BorderSide(
          color: _Palette.salmon
              .withOpacity(0.18),
        ),
      ),
    );
  }
}