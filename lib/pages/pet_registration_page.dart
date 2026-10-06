import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: unused_import
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
  static const Color honey = Color(0xFFE0A438);
  static const Color leaf = Color(0xFF6FAE7C);
}

class PetRegistrationPage extends StatefulWidget {
  const PetRegistrationPage({super.key});

  @override
  State<PetRegistrationPage> createState() => _PetRegistrationPageState();
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
      if (userId == null) throw Exception('User is not logged in.');

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
        onPetTypeChanged: (value) => _petType = value,
        onGenderChanged: (value) => _gender = value,
        onSubmit: (selectedImages) async {
          final success = await _savePet(selectedImages);
          if (success && mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // ============================================================
  // SHOW EDIT DIALOG
  // ============================================================

  Future<void> _showEditDialog(Map<String, dynamic> pet) async {
    setState(() {
      _editingPetId = pet['id'] as int;
      _nameController.text = pet['pet_name']?.toString() ?? '';
      _petType = pet['pet_type']?.toString() ?? 'Dog';
      _ageController.text = pet['age']?.toString() ?? '';
      _gender = pet['gender']?.toString() ?? 'Male';
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
        onPetTypeChanged: (value) => _petType = value,
        onGenderChanged: (value) => _gender = value,
        onSubmit: (selectedImages) async {
          final success = await _savePet(selectedImages);
          if (success && mounted) Navigator.pop(context);
        },
      ),
    );
  }

  // ============================================================
  // SAVE PET
  // ============================================================

  Future<bool> _savePet(List<XFile> selectedImages) async {
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

    if (_editingPetId == null && selectedImages.isEmpty) {
      _showMessage('Please add at least one photo of your pet.');
      return false;
    }

    if (!mounted) return false;

    setState(() => _loading = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User is not logged in.');

      final data = {
        'owner_id': userId,
        'pet_name': name,
        'pet_type': _petType,
        'age': age,
        'gender': _gender,
      };

      if (_editingPetId == null) {
        final insertedPet = await _supabase
            .from('pets')
            .insert(data)
            .select('id')
            .single();

        final petId = insertedPet['id'] as int;

        final photoPaths = await _uploadPetPhotos(petId, selectedImages);

        await _supabase
            .from('pets')
            .update({'photo_paths': photoPaths})
            .eq('id', petId)
            .eq('owner_id', userId);

        _showMessage('Pet registered with ${photoPaths.length} photo(s) 🐾');
      } else {
        await _supabase
            .from('pets')
            .update(data)
            .eq('id', _editingPetId as int)
            .eq('owner_id', userId);

        if (selectedImages.isNotEmpty) {
          final photoPaths = await _uploadPetPhotos(
            _editingPetId as int,
            selectedImages,
          );

          await _supabase
              .from('pets')
              .update({'photo_paths': photoPaths})
              .eq('id', _editingPetId as int)
              .eq('owner_id', userId);

          _showMessage('Pet updated with ${photoPaths.length} photo(s) 🐾');
        } else {
          _showMessage('Pet updated successfully 🐾');
        }
      }

      _clearForm();
      await _fetchPets();
      return true;
    } catch (e) {
      _showMessage('Error: $e');
      return false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ============================================================
  // UPLOAD PET PHOTOS
  // ============================================================

  Future<List<String>> _uploadPetPhotos(int petId, List<XFile> images) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User is not logged in.');

    final uploadedPaths = <String>[];

    for (int i = 0; i < images.length; i++) {
      final image = images[i];
      final Uint8List bytes = await image.readAsBytes();

      String extension = 'jpg';
      if (image.name.contains('.')) {
        extension = image.name.split('.').last.toLowerCase();
        if (extension == 'jpeg') extension = 'jpg';
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$userId/pet_$petId/${timestamp}_$i.$extension';

      String contentType = 'image/jpeg';
      if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'webp') {
        contentType = 'image/webp';
      }

      await _supabase.storage.from('pet-photos').uploadBinary(
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
          borderRadius: BorderRadius.circular(28),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete pet?',
              style: GoogleFonts.fraunces(
                fontWeight: FontWeight.w800,
                color: _Palette.brownSoft,
                fontSize: 19,
              ),
            ),
          ],
        ),
        content: Text(
          'This pet profile will be removed permanently. 🐾',
          style: GoogleFonts.dmSans(
            color: _Palette.brownSoft.withOpacity(0.8),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(color: _Palette.muted),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User is not logged in.');

      final pet = await _supabase
          .from('pets')
          .select('photo_paths')
          .eq('id', id)
          .eq('owner_id', userId)
          .maybeSingle();

      if (pet != null) {
        final photoPaths = pet['photo_paths'];
        if (photoPaths is List && photoPaths.isNotEmpty) {
          final paths = photoPaths.map((e) => e.toString()).toList();
          try {
            await _supabase.storage.from('pet-photos').remove(paths);
          } catch (_) {}
        }
      }

      await _supabase
          .from('pets')
          .delete()
          .eq('id', id)
          .eq('owner_id', userId);

      await _fetchPets();
      _showMessage('Pet deleted.');
    } catch (e) {
      _showMessage('Error deleting pet: $e');
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

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _Palette.peach,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
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
        child: Stack(
          children: [
            // ---- SOFT BLOBS ----
            Positioned(
              top: -60,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _Palette.salmon.withOpacity(0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _Palette.cream.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ---- GHOST PAWS ----
            Positioned(
              top: 160,
              right: 10,
              child: Transform.rotate(
                angle: 0.4,
                child: Icon(
                  Icons.pets,
                  size: 38,
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
            ),
            Positioned(
              bottom: 180,
              left: 6,
              child: Transform.rotate(
                angle: -0.3,
                child: Icon(
                  Icons.pets,
                  size: 44,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ),

            SafeArea(
              child: RefreshIndicator(
                color: _Palette.salmon,
                onRefresh: _fetchPets,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 150),
                  children: [
                    // =========================
                    // HEADER
                    // =========================
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_Palette.salmon, _Palette.peach],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _Palette.salmon.withOpacity(0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.pets,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My Pets',
                                style: GoogleFonts.fraunces(
                                  color: _Palette.brownSoft,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Manage your furry family 🐾',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _Palette.brownSoft.withOpacity(0.6),
                                ),
                              ),
                            ],
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
                      height: 60,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [_Palette.salmon, _Palette.peach],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _Palette.salmon.withOpacity(0.45),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: FilledButton.icon(
                          onPressed: _showRegisterDialog,
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                          label: Text(
                            'Register a Pet',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.9),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _Palette.brownSoft.withOpacity(0.09),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _Palette.blush.withOpacity(0.9),
                                  _Palette.cream.withOpacity(0.9),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: _Palette.salmon.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.pets_rounded,
                              color: _Palette.salmon,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_pets.length} Registered Pet${_pets.length == 1 ? '' : 's'}',
                                  style: GoogleFonts.fraunces(
                                    color: _Palette.brown,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                Text(
                                  _pets.isEmpty
                                      ? 'Add your first furry friend'
                                      : 'Tap a card to edit or delete',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: _Palette.brownSoft.withOpacity(0.55),
                                  ),
                                ),
                              ],
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
                      ..._pets.map((pet) => _petCard(pet)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _Palette.blush.withOpacity(0.7),
                        _Palette.blush.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 14,
                  child: Icon(
                    Icons.pets,
                    size: 16,
                    color: _Palette.salmon.withOpacity(0.55),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 8,
                  child: Icon(
                    Icons.pets,
                    size: 13,
                    color: _Palette.peach.withOpacity(0.7),
                  ),
                ),
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_Palette.salmon, _Palette.peach],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _Palette.salmon.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.pets_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No pets yet',
            style: GoogleFonts.fraunces(
              color: _Palette.brownSoft,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap "Register a Pet" to add your first furry friend. 🐾',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: _Palette.brownSoft.withOpacity(0.65),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GET PET STORAGE PHOTOS
  // ============================================================

  Future<List<String>> _getPetStoragePhotos(int petId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final folderPath = '$userId/pet_$petId';

      debugPrint('Looking for pet photos in: $folderPath');

      final files = await _supabase.storage
          .from('pet-photos')
          .list(path: folderPath);

      final paths = <String>[];

      for (final file in files) {
        final name = file.name.toLowerCase();
        if (name.endsWith('.jpg') ||
            name.endsWith('.jpeg') ||
            name.endsWith('.png') ||
            name.endsWith('.webp')) {
          paths.add('$folderPath/${file.name}');
        }
      }

      debugPrint('Found ${paths.length} photos for pet $petId');
      return paths;
    } catch (e) {
      debugPrint('Error retrieving pet $petId photos: $e');
      return [];
    }
  }

  // ============================================================
  // PET CARD
  // ============================================================

  Widget _petCard(Map<String, dynamic> pet) {
    final id = pet['id'] as int;
    final name = pet['pet_name']?.toString() ?? 'Pet';
    final type = pet['pet_type']?.toString() ?? 'Pet';
    final age = pet['age']?.toString() ?? '0';
    final gender = pet['gender']?.toString() ?? '';

    final accent = _accentForPetType(type);

    return FutureBuilder<List<String>>(
      future: _getPetStoragePhotos(id),
      builder: (context, snapshot) {
        final photoPaths = snapshot.data ?? [];
        final hasPhotos = photoPaths.isNotEmpty;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: accent.withOpacity(0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: _Palette.brownSoft.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Left accent bar
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [accent, accent.withOpacity(0.4)],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                  child: Row(
                    children: [
                      // ==========================================
                      // PET IMAGE
                      // ==========================================
                      Container(
                        width: 72,
                        height: 72,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent.withOpacity(0.9),
                              accent.withOpacity(0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: snapshot.connectionState ==
                                ConnectionState.waiting
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : hasPhotos
                                ? FutureBuilder<String>(
                                    future: _supabase.storage
                                        .from('pet-photos')
                                        .createSignedUrl(
                                          photoPaths.first,
                                          3600,
                                        ),
                                    builder: (context, urlSnapshot) {
                                      if (urlSnapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Center(
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      }

                                      if (urlSnapshot.hasError ||
                                          !urlSnapshot.hasData) {
                                        return const Icon(
                                          Icons.pets_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        );
                                      }

                                      return Image.network(
                                        urlSnapshot.data!,
                                        fit: BoxFit.cover,
                                        width: 72,
                                        height: 72,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.pets_rounded,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      );
                                    },
                                  )
                                : const Icon(
                                    Icons.pets_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                      ),

                      const SizedBox(width: 14),

                      // ==========================================
                      // PET INFO
                      // ==========================================
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.fraunces(
                                color: _Palette.brown,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _InfoPill(
                                  icon: _iconForPetType(type),
                                  label: type,
                                  color: accent,
                                ),
                                _InfoPill(
                                  icon: gender == 'Female'
                                      ? Icons.female_rounded
                                      : Icons.male_rounded,
                                  label: gender,
                                  color: _Palette.leaf,
                                ),
                                _InfoPill(
                                  icon: Icons.cake_rounded,
                                  label: '$age yr${age == '1' ? '' : 's'}',
                                  color: _Palette.honey,
                                ),
                              ],
                            ),
                            if (hasPhotos) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _Palette.cream.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _Palette.honey.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.photo_library_rounded,
                                      size: 11,
                                      color: _Palette.honey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${photoPaths.length} photo${photoPaths.length == 1 ? '' : 's'}',
                                      style: GoogleFonts.dmSans(
                                        color: _Palette.brownSoft,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // ==========================================
                      // MENU
                      // ==========================================
                      PopupMenuButton<String>(
                        color: Colors.white,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.more_vert_rounded,
                            size: 18,
                            color: accent,
                          ),
                        ),
                        onSelected: (value) {
                          if (value == 'edit') _showEditDialog(pet);
                          if (value == 'delete') _deletePet(id);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.edit_rounded,
                                  size: 18,
                                  color: _Palette.salmon,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Edit',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    color: _Palette.brownSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    color: _Palette.brownSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  Color _accentForPetType(String type) {
    switch (type.toLowerCase()) {
      case 'cat':
        return _Palette.peach;
      case 'bird':
        return _Palette.leaf;
      case 'rabbit':
        return _Palette.honey;
      case 'dog':
      default:
        return _Palette.salmon;
    }
  }

  IconData _iconForPetType(String type) {
    switch (type.toLowerCase()) {
      case 'cat':
        return Icons.pets_rounded;
      case 'bird':
        return Icons.flutter_dash_rounded;
      case 'rabbit':
        return Icons.cruelty_free_rounded;
      default:
        return Icons.pets_rounded;
    }
  }

  // ============================================================
  // CARD DECORATION
  // ============================================================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.94),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(
        color: Colors.white.withOpacity(0.9),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: _Palette.brownSoft.withOpacity(0.1),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

// ===================================================================
// INFO PILL (small metadata chip)
// ===================================================================

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: _Palette.brownSoft,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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

  final ValueChanged<String> onPetTypeChanged;
  final ValueChanged<String> onGenderChanged;

  final Future<void> Function(List<XFile> selectedImages) onSubmit;

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
  State<_PetFormDialog> createState() => _PetFormDialogState();
}

class _PetFormDialogState extends State<_PetFormDialog> {
  late String _selectedPetType;
  late String _selectedGender;

  final ImagePicker _picker = ImagePicker();

  List<XFile> _selectedImages = [];
  bool _selectingPhotos = false;

  @override
  void initState() {
    super.initState();
    _selectedPetType = widget.petType;
    _selectedGender = widget.gender;
  }

  // ============================================================
  // PICK PHOTOS
  // ============================================================

  Future<void> _selectPhotos() async {
    if (_selectingPhotos) return;

    setState(() => _selectingPhotos = true);

    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (images.isEmpty) return;
      if (!mounted) return;

      setState(() {
        _selectedImages = images.take(20).toList();
      });

      if (images.length > 20) {
        _showMessage('Only the first 20 photos were selected.');
      }
    } catch (e) {
      _showMessage('Error selecting photos: $e');
    } finally {
      if (mounted) setState(() => _selectingPhotos = false);
    }
  }

  // ============================================================
  // REMOVE PHOTO
  // ============================================================

  void _removePhoto(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        backgroundColor: _Palette.peach,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFDF9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 6),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_Palette.salmon, _Palette.peach],
              ),
              boxShadow: [
                BoxShadow(
                  color: _Palette.salmon.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.pets,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: GoogleFonts.fraunces(
                color: _Palette.brownSoft,
                fontWeight: FontWeight.w800,
                fontSize: 19,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),

      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _input(
                controller: widget.nameController,
                label: 'Pet Name',
                icon: Icons.badge_rounded,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedPetType,
                style: GoogleFonts.dmSans(
                  color: _Palette.brown,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _inputDecoration(
                  label: 'Pet Type',
                  icon: Icons.pets_rounded,
                ),
                items: const [
                  DropdownMenuItem(value: 'Dog', child: Text('🐶  Dog')),
                  DropdownMenuItem(value: 'Cat', child: Text('🐱  Cat')),
                  DropdownMenuItem(value: 'Bird', child: Text('🐦  Bird')),
                  DropdownMenuItem(value: 'Rabbit', child: Text('🐰  Rabbit')),
                  DropdownMenuItem(value: 'Other', child: Text('🐾  Other')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedPetType = value);
                  widget.onPetTypeChanged(value);
                },
              ),
              const SizedBox(height: 14),
              _input(
                controller: widget.ageController,
                label: 'Age',
                icon: Icons.cake_rounded,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                style: GoogleFonts.dmSans(
                  color: _Palette.brown,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: _inputDecoration(
                  label: 'Gender',
                  icon: Icons.wc_rounded,
                ),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('♂  Male')),
                  DropdownMenuItem(value: 'Female', child: Text('♀  Female')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedGender = value);
                  widget.onGenderChanged(value);
                },
              ),

              const SizedBox(height: 22),

              // ==================================================
              // PHOTO SECTION
              // ==================================================
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _Palette.salmon.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.photo_library_rounded,
                        color: _Palette.salmon,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pet Photos',
                      style: GoogleFonts.fraunces(
                        color: _Palette.brown,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add clear photos of your pet from different angles for better AI recognition.',
                  style: GoogleFonts.dmSans(
                    color: _Palette.muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // ADD PHOTOS BUTTON
              // ==================================================
              InkWell(
                onTap: widget.loading || _selectingPhotos ? null : _selectPhotos,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _Palette.blush.withOpacity(0.4),
                        _Palette.cream.withOpacity(0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _Palette.salmon.withOpacity(0.4),
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    children: [
                      if (_selectingPhotos)
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: _Palette.salmon,
                            strokeWidth: 2.5,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _Palette.salmon.withOpacity(0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_a_photo_rounded,
                            color: _Palette.salmon,
                            size: 26,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Text(
                        _selectedImages.isEmpty
                            ? 'Add Photos'
                            : 'Change Photos',
                        style: GoogleFonts.dmSans(
                          color: _Palette.brown,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _selectedImages.isEmpty
                            ? 'Select up to 20 photos'
                            : '${_selectedImages.length} photo${_selectedImages.length == 1 ? '' : 's'} selected',
                        style: GoogleFonts.dmSans(
                          color: _Palette.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ==================================================
              // PHOTO PREVIEW
              // ==================================================
              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return FutureBuilder<Uint8List>(
                        future: _selectedImages[index].readAsBytes(),
                        builder: (context, snapshot) {
                          return Container(
                            width: 90,
                            height: 90,
                            margin: const EdgeInsets.only(right: 10),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: snapshot.hasData
                                      ? Image.memory(
                                          snapshot.data!,
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 90,
                                          height: 90,
                                          color: _Palette.blush
                                              .withOpacity(0.4),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: _Palette.salmon,
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                ),
                                // Subtle border overlay
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.9),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removePhoto(index),
                                    child: Container(
                                      width: 25,
                                      height: 25,
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.red.withOpacity(0.4),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 14,
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

              if (widget.requirePhoto && _selectedImages.isEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'At least one pet photo is required.',
                          style: GoogleFonts.dmSans(
                            color: Colors.redAccent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
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
      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      actions: [
        TextButton(
          onPressed:
              widget.loading ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.dmSans(
              color: _Palette.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [_Palette.salmon, _Palette.peach],
            ),
            boxShadow: [
              BoxShadow(
                color: _Palette.salmon.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: widget.loading || _selectingPhotos
                ? null
                : () async {
                    await widget.onSubmit(_selectedImages);
                  },
            icon: widget.loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.pets_rounded, size: 18),
            label: Text(
              widget.buttonText,
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.dmSans(
        color: _Palette.brown,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: _inputDecoration(label: label, icon: icon),
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
      labelStyle: GoogleFonts.dmSans(
        color: _Palette.muted,
        fontWeight: FontWeight.w600,
      ),
      floatingLabelStyle: GoogleFonts.dmSans(
        color: _Palette.salmon,
        fontWeight: FontWeight.w800,
      ),
      prefixIcon: Icon(icon, color: _Palette.salmon),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 12,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: _Palette.salmon,
          width: 1.6,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: _Palette.salmon.withOpacity(0.2),
          width: 1.2,
        ),
      ),
    );
  }
}