class AuthResponse {
  final String accessToken, refreshToken;
  final int expiresIn;
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });
  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
    accessToken: j['accessToken'] as String,
    refreshToken: j['refreshToken'] as String,
    expiresIn: (j['expiresIn'] as num?)?.toInt() ?? 900,
  );
}

class UserProfile {
  final String id, username, rol, createdAt;
  final int nivel;
  final String? sedeId;
  final String? sede;
  final List<String> permisos;
  const UserProfile({
    required this.id,
    required this.username,
    required this.rol,
    required this.nivel,
    this.sedeId,
    this.sede,
    required this.createdAt,
    required this.permisos,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id: j['id'] as String? ?? j['sub'] as String? ?? '',
    username: j['username'] as String? ?? '',
    rol: j['rol'] as String? ?? '',
    nivel: (j['nivel'] as num?)?.toInt() ?? 0,
    sedeId: j['sedeId'] as String?,
    sede: j['sede'] as String?,
    createdAt: j['createdAt'] as String? ?? '',
    permisos: (j['permisos'] as List?)?.cast<String>() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'rol': rol,
    'nivel': nivel,
    'sedeId': sedeId,
    'sede': sede,
    'createdAt': createdAt,
    'permisos': permisos,
  };

  bool hasPermission(String p) => permisos.contains(p);
  bool get isSuperAdmin => rol.toUpperCase() == 'SUPERADMIN';
  bool get isAdmin => rol.toUpperCase() == 'ADMIN';
  String get sedeName => sede ?? '';
}

class ActiveSession {
  final String id;
  final String? deviceName, deviceType, ip, lastUsedAt, createdAt;
  final bool isCurrent;
  const ActiveSession({
    required this.id,
    this.deviceName,
    this.deviceType,
    this.ip,
    this.lastUsedAt,
    this.createdAt,
    required this.isCurrent,
  });
  factory ActiveSession.fromJson(Map<String, dynamic> j) => ActiveSession(
    id: j['id'] as String,
    deviceName: j['deviceName'] as String?,
    deviceType: j['deviceType'] as String?,
    ip: j['ip'] as String?,
    lastUsedAt: j['lastUsedAt'] as String?,
    createdAt: j['createdAt'] as String?,
    isCurrent: j['actual'] as bool? ?? false,
  );
}
