import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';


class UsersAdminPage extends StatefulWidget {
  final String jwt;

  const UsersAdminPage({super.key, required this.jwt});

  @override
  State<UsersAdminPage> createState() => _UsersAdminPageState();
}

class _UsersAdminPageState extends State<UsersAdminPage> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  bool loading = true;
  String? errorMessage;

  List<UserItem> users = [];
  List<CourseItem> courses = [];

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final jwt = widget.jwt;

      final usersUrl = Uri.parse(ApiConfig.adminUsers);
      final coursesUrl = Uri.parse(ApiConfig.courses);

      final usersResponse = await http.get(
        usersUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
      );

      final coursesResponse = await http.get(
        coursesUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $jwt',
        },
      );

      if (usersResponse.statusCode == 401 || coursesResponse.statusCode == 401) {
        await secureStorage.delete(key: 'jwt');
        if (!mounted) return;

        setState(() {
          loading = false;
          errorMessage = 'Sesión caducada. Vuelve a iniciar sesión.';
        });
        return;
      }

      if (usersResponse.statusCode != 200) {
        setState(() {
          loading = false;
          errorMessage =
          'No se pudo cargar la lista de usuarios (${usersResponse.statusCode})';
        });
        return;
      }

      if (coursesResponse.statusCode != 200) {
        setState(() {
          loading = false;
          errorMessage =
          'No se pudo cargar la lista de ciclos (${coursesResponse.statusCode})';
        });
        return;
      }

      final usersJson = jsonDecode(usersResponse.body) as List;
      final coursesJson = jsonDecode(coursesResponse.body) as List;

      setState(() {
        users = usersJson.map((e) => UserItem.fromJson(e)).toList();
        courses = coursesJson.map((e) => CourseItem.fromJson(e)).toList();
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        errorMessage = 'Error cargando datos: $e';
      });
    }
  }

  Future<void> borrarUsuario(UserItem user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text(
          '¿Seguro que quieres eliminar al usuario "${user.username}"?\n'
              'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final url =
      Uri.parse('${ApiConfig.adminUsers}/${user.id}');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwt}',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          users.removeWhere((u) => u.id == user.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuario "${user.username}" eliminado')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar usuario: ${response.body}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar usuario: $e')),
      );
    }
  }

  Future<void> resetPassword(UserItem user) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resetear contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Introduce la nueva contraseña para "${user.username}".',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('La contraseña no puede estar vacía'),
                  ),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Resetear'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final newPassword = controller.text.trim();

    try {
      final url = Uri.parse(
        '${ApiConfig.adminUsers}/${user.id}/reset-password',
      );
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwt}',
        },
        body: jsonEncode({'newPassword': newPassword}),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Contraseña reseteada para "${user.username}"')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Error al resetear contraseña: ${response.body}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al resetear contraseña: $e')),
      );
    }
  }

  Future<void> mostrarDialogUsuario({UserItem? user}) async {
    final isEditing = user != null;

    final usernameController =
    TextEditingController(text: user?.username ?? '');
    final emailController =
    TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();

    String role = user?.role ?? 'ADMINISTRACION';
    Set<int> selectedCourseIds = {};

    if (user != null && user.coordinatorCourses.isNotEmpty) {
      selectedCourseIds = user.coordinatorCourses
          .map((c) => c.id)
          .toSet();
    }

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final isCoordinador = role == 'COORDINADOR';

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Editar usuario' : 'Crear usuario',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de usuario',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre de usuario es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El email es obligatorio';
                          }
                          if (!value.contains('@')) {
                            return 'Email no válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: role,
                        decoration: const InputDecoration(
                          labelText: 'Rol',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ADMIN',
                            child: Text('ADMIN'),
                          ),
                          DropdownMenuItem(
                            value: 'ADMINISTRACION',
                            child: Text('ADMINISTRACION'),
                          ),
                          DropdownMenuItem(
                            value: 'COORDINADOR',
                            child: Text('COORDINADOR'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setStateDialog(() {
                            role = value;
                            if (role != 'COORDINADOR') {
                              selectedCourseIds.clear();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (!isEditing) ...[
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (!isEditing &&
                                (value == null || value.trim().isEmpty)) {
                              return 'La contraseña es obligatoria';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ] else ...[
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Nueva contraseña (opcional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (role == 'COORDINADOR') ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Ciclos coordinados',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (courses.isEmpty)
                          const Text(
                              'No hay ciclos disponibles en el sistema')
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: courses.map((course) {
                              final selected =
                              selectedCourseIds.contains(course.id);
                              return FilterChip(
                                label: Text(course.name),
                                selected: selected,
                                onSelected: (_) {
                                  setStateDialog(() {
                                    if (selected) {
                                      selectedCourseIds.remove(course.id);
                                    } else {
                                      selectedCourseIds.add(course.id);
                                    }
                                  });
                                },
                                selectedColor:
                                Colors.blue.withOpacity(0.15),
                                checkmarkColor: Colors.blue.shade700,
                                side: BorderSide(
                                  color: selected
                                      ? Colors.blue.withOpacity(0.35)
                                      : Colors.grey.withOpacity(0.25),
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Seleccionados: ${selectedCourseIds.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    if (role == 'COORDINADOR' &&
                        selectedCourseIds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Selecciona al menos un ciclo para el coordinador'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: Text(isEditing ? 'Guardar' : 'Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password =
    passwordController.text.trim().isEmpty ? null : passwordController.text.trim();

    final body = {
      'username': username,
      'email': email,
      'role': role,
      'password': password,
      'courseIds': role == 'COORDINADOR'
          ? selectedCourseIds.toList()
          : [],
    };

    try {
      if (isEditing) {
        final url = Uri.parse(
          '${ApiConfig.adminUsers}/${user!.id}',
        );
        final response = await http.put(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.jwt}',
          },
          body: jsonEncode(body),
        );

        if (response.statusCode == 200) {
          await cargarDatos();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Usuario "${username}" actualizado'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Error al actualizar usuario: ${response.body}'),
            ),
          );
        }
      } else {
        final url = Uri.parse(
          ApiConfig.adminUsers,
        );
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.jwt}',
          },
          body: jsonEncode(body),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await cargarDatos();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Usuario "${username}" creado'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Error al crear usuario: ${response.body}'),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar usuario: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administración de usuarios')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              errorMessage!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: cargarDatos,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración de usuarios'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            onPressed: cargarDatos,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Crear usuario',
            onPressed: () => mostrarDialogUsuario(),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 52,
            dataRowMinHeight: 56,
            dataRowMaxHeight: 72,
            columns: const [
              DataColumn(label: Text('Usuario')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Rol')),
              DataColumn(label: Text('Ciclos coordinador')),
              DataColumn(label: Text('Proveedor')),
              DataColumn(label: Text('Acciones')),
            ],
            rows: users.map((user) {
              final coursesText = user.coordinatorCourses.isEmpty
                  ? '-'
                  : user.coordinatorCourses.map((c) => c.name).join(', ');

              return DataRow(
                cells: [
                  DataCell(Text(user.username)),
                  DataCell(Text(user.email)),
                  DataCell(Text(user.role)),
                  DataCell(Text(coursesText)),
                  DataCell(Text(user.authProvider ?? '-')),
                  DataCell(
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Editar',
                          icon: const Icon(Icons.edit),
                          onPressed: () => mostrarDialogUsuario(user: user),
                        ),
                        IconButton(
                          tooltip: 'Resetear contraseña',
                          icon: const Icon(Icons.lock_reset),
                          onPressed: () => resetPassword(user),
                        ),
                        IconButton(
                          tooltip: 'Eliminar',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => borrarUsuario(user),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => mostrarDialogUsuario(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo usuario'),
      ),
    );
  }
}

class UserItem {
  final int id;
  final String username;
  final String email;
  final String role;
  final bool googleLinked;
  final String? authProvider;
  final List<CourseItem> coordinatorCourses;

  UserItem({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.googleLinked,
    required this.authProvider,
    required this.coordinatorCourses,
  });

  factory UserItem.fromJson(Map<String, dynamic> json) {
    final coursesJson = json['coordinatorCourses'] as List? ?? [];
    return UserItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      googleLinked: json['googleLinked'] == true,
      authProvider: json['authProvider']?.toString(),
      coordinatorCourses: coursesJson
          .map((e) => CourseItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CourseItem {
  final int id;
  final String name;

  CourseItem({
    required this.id,
    required this.name,
  });

  factory CourseItem.fromJson(Map<String, dynamic> json) {
    return CourseItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      name: (json['name'] ?? '').toString(),
    );
  }
}