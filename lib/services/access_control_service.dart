class AccessControlService {
  static const String actionCreate = 'create';
  static const String actionRead = 'read';
  static const String actionUpdate = 'update';
  static const String actionDelete = 'delete';

  static final Map<String, List<String>> _rolePermissions = {
    'Ketua': [actionCreate, actionRead, actionUpdate, actionDelete],
    'Anggota': [actionCreate, actionRead],
    'Asisten': [actionRead, actionUpdate],
  };

  static bool canPerform(String role, String action, {bool isOwner = false}) {
    final permissions = _rolePermissions[role] ?? [];

    // Sovereignty Rule: Aksi update/delete hanya boleh dilakukan oleh pemilik
    if (action == actionUpdate || action == actionDelete) {
      return isOwner;
    }

    return permissions.contains(action);
  }

  // Visibility Rule: Catatan private hanya bisa dilihat oleh pemiliknya
  static bool canView({required bool isOwner, required bool isPublic}) {
    return isOwner || isPublic;
  }
}
