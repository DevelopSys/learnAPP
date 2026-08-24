import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

const Color accentColor = Color(0xFF3ECF8E);

class UsersAdminPage extends StatefulWidget {
  final String jwt;

  const UsersAdminPage({
    super.key,
    required this.jwt,
  });

  @override
  State<UsersAdminPage> createState() => _UsersAdminPageState();
}

class _UsersAdminPageState extends State<UsersAdminPage> {
  final FlutterSecureStorage secureStorage =
  const FlutterSecureStorage();

  bool loading = true;
  String? errorMessage;

  List<UserItem> users = [];
  List<CourseItem> courses = [];



  Map<String, String> get requestHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.jwt}',
  };

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<UserItem?> cargarUsuarioPorId(int userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.adminUsers}/$userId'),
        headers: requestHeaders,
      );

      if (!mounted) return null;

      if (response.statusCode != 200) {
        _showMessage(
          'No se pudieron cargar los datos del usuario: '
              '${_responseMessage(response)}',
        );
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      return UserItem.fromJson(json);
    } catch (e) {
      if (!mounted) return null;

      _showMessage('Error cargando usuario: $e');
      return null;
    }
  }

  Future<void> cargarDatos() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final usersResponse = await http.get(
        Uri.parse(ApiConfig.adminUsers),
        headers: requestHeaders,
      );

      final coursesResponse = await http.get(
        Uri.parse(ApiConfig.courses),
        headers: requestHeaders,
      );

      if (usersResponse.statusCode == 401 ||
          coursesResponse.statusCode == 401) {
        await secureStorage.delete(key: 'jwt');

        if (!mounted) return;

        setState(() {
          loading = false;
          errorMessage = 'Sesión caducada. Vuelve a iniciar sesión.';
        });
        return;
      }

      if (usersResponse.statusCode != 200) {
        if (!mounted) return;

        setState(() {
          loading = false;
          errorMessage = 'No se pudo cargar la lista de usuarios '
              '(${usersResponse.statusCode})';
        });
        return;
      }

      if (coursesResponse.statusCode != 200) {
        if (!mounted) return;

        setState(() {
          loading = false;
          errorMessage = 'No se pudo cargar la lista de ciclos '
              '(${coursesResponse.statusCode})';
        });
        return;
      }

      final usersJson = jsonDecode(usersResponse.body) as List;
      final coursesJson = jsonDecode(coursesResponse.body) as List;

      final loadedUsers = usersJson
          .map(
            (item) => UserItem.fromJson(
          item as Map<String, dynamic>,
        ),
      )
          .toList();

      final loadedCourses = coursesJson
          .map(
            (item) => CourseItem.fromJson(
          item as Map<String, dynamic>,
        ),
      )
          .toList();

      if (!mounted) return;

      setState(() {
        users = loadedUsers;
        courses = loadedCourses;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

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
          '¿Seguro que quieres eliminar al usuario '
              '"${user.username}"?\n\n'
              'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.adminUsers}/${user.id}'),
        headers: requestHeaders,
      );

      if (!mounted) return;

      if (_isSuccess(response)) {
        setState(() {
          users.removeWhere((item) => item.id == user.id);
        });

        _showMessage('Usuario "${user.username}" eliminado');
      } else {
        _showMessage(
          'Error al eliminar usuario: '
              '${_responseMessage(response)}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage('Error al eliminar usuario: $e');
    }
  }

  Future<void> borrarCurso(CourseItem course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar ciclo'),
        content: Text(
          '¿Seguro que quieres eliminar el ciclo '
              '"${course.name}"?\n\n'
              'Se eliminarán sus relaciones de coordinación y '
              'resultados de aprendizaje. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.courses}/${course.id}'),
        headers: requestHeaders,
      );

      if (!mounted) return;

      if (_isSuccess(response)) {
        setState(() {
          courses.removeWhere((item) => item.id == course.id);

          for (final user in users) {
            user.coordinatorCourses.removeWhere(
                  (assignedCourse) =>
              assignedCourse.id == course.id,
            );
          }
        });

        _showMessage(
          'Ciclo "${course.name}" eliminado correctamente',
        );
      } else {
        _showMessage(
          'Error al eliminar ciclo: '
              '${_responseMessage(response)}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage('Error al eliminar ciclo: $e');
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
              'Introduce la nueva contraseña para '
                  '"${user.username}".',
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
                _showMessage(
                  'La contraseña no puede estar vacía',
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

    try {
      final response = await http.put(
        Uri.parse(
          '${ApiConfig.adminUsers}/${user.id}/reset-password',
        ),
        headers: requestHeaders,
        body: jsonEncode({
          'newPassword': controller.text.trim(),
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        _showMessage(
          'Contraseña reseteada para "${user.username}"',
        );
      } else {
        _showMessage(
          'Error al resetear contraseña: '
              '${_responseMessage(response)}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage('Error al resetear contraseña: $e');
    }
  }

  Future<void> mostrarDialogUsuario({UserItem? user}) async {
    final bool isEditing = user != null;

    final usernameController = TextEditingController(
      text: user?.username ?? '',
    );

    final emailController = TextEditingController(
      text: user?.email ?? '',
    );

    final passwordController = TextEditingController();

    String selectedRole = user?.role.toUpperCase() ?? 'ADMINISTRACION';

    Set<int> selectedCourseIds = user?.coordinatorCourses
        .map((course) => course.id)
        .toSet() ??
        <int>{};

    final coordinatorDniController = TextEditingController(
      text: user?.coordinatorDni ?? '',
    );

    final coordinatorNameController = TextEditingController(
      text: user?.coordinatorName ?? '',
    );

    final coordinatorSurnameController = TextEditingController(
      text: user?.coordinatorSurname ?? '',
    );

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            final isCoordinator =
                selectedRole == 'COORDINADOR';

            return AlertDialog(
              title: Text(
                isEditing ? 'Editar usuario' : 'Añadir usuario',
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              content: SizedBox(
                width: 520,
                height:
                MediaQuery.of(dialogContext).size.height * 0.70,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
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
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'El nombre de usuario '
                                  'es obligatorio';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
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
                          value: selectedRole,
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
                              selectedRole = value;

                              if (selectedRole !=
                                  'COORDINADOR') {
                                selectedCourseIds.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: isEditing
                                ? 'Nueva contraseña (opcional)'
                                : 'Contraseña',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (!isEditing &&
                                (value == null ||
                                    value.trim().isEmpty)) {
                              return 'La contraseña es obligatoria';
                            }

                            return null;
                          },
                        ),

                        if (isCoordinator) ...[
                          const SizedBox(height: 20),

                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Datos del coordinador',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextFormField(
                            controller: coordinatorDniController,
                            decoration: const InputDecoration(
                              labelText: 'DNI del coordinador',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'El DNI del coordinador '
                                    'es obligatorio';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          TextFormField(
                            controller: coordinatorNameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre del coordinador',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'El nombre del coordinador '
                                    'es obligatorio';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          TextFormField(
                            controller: coordinatorSurnameController,
                            decoration: const InputDecoration(
                              labelText: 'Apellidos del coordinador',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Los apellidos del coordinador '
                                    'son obligatorios';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Ciclos coordinados',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(dialogContext)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          if (courses.isEmpty)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'No hay ciclos disponibles '
                                    'en el sistema',
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: courses.map((course) {
                                final selected =
                                selectedCourseIds.contains(
                                  course.id,
                                );

                                return FilterChip(
                                  label: Text(course.name),
                                  selected: selected,
                                  onSelected: (_) {
                                    setStateDialog(() {
                                      if (selected) {
                                        selectedCourseIds.remove(
                                          course.id,
                                        );
                                      } else {
                                        selectedCourseIds.add(
                                          course.id,
                                        );
                                      }
                                    });
                                  },
                                  selectedColor:
                                  Colors.blue.withOpacity(0.15),
                                  checkmarkColor:
                                  Colors.blue.shade700,
                                );
                              }).toList(),
                            ),

                          const SizedBox(height: 8),

                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Seleccionados: '
                                  '${selectedCourseIds.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(dialogContext)
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
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    if (isCoordinator &&
                        selectedCourseIds.isEmpty) {
                      _showMessage(
                        'Selecciona al menos un ciclo '
                            'para el coordinador',
                      );
                      return;
                    }

                    Navigator.of(dialogContext).pop(true);
                  },
                  child: Text(
                    isEditing
                        ? 'Guardar cambios'
                        : 'Crear usuario',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final body = {
      'username': usernameController.text.trim(),
      'email': emailController.text.trim(),
      'role': selectedRole,
      'password': passwordController.text.trim().isEmpty
          ? null
          : passwordController.text.trim(),
      'courseIds': selectedRole == 'COORDINADOR'
          ? selectedCourseIds.toList()
          : [],
      'coordinatorDni': selectedRole == 'COORDINADOR'
          ? coordinatorDniController.text.trim()
          : null,
      'coordinatorName': selectedRole == 'COORDINADOR'
          ? coordinatorNameController.text.trim()
          : null,
      'coordinatorSurname': selectedRole == 'COORDINADOR'
          ? coordinatorSurnameController.text.trim()
          : null,
    };

    try {
      final Uri url = isEditing
          ? Uri.parse('${ApiConfig.adminUsers}/${user!.id}')
          : Uri.parse(ApiConfig.adminUsers);

      final response = isEditing
          ? await http.put(
        url,
        headers: requestHeaders,
        body: jsonEncode(body),
      )
          : await http.post(
        url,
        headers: requestHeaders,
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        await cargarDatos();

        if (!mounted) return;

        _showMessage(
          isEditing
              ? 'Usuario "${usernameController.text.trim()}" '
              'actualizado'
              : 'Usuario "${usernameController.text.trim()}" '
              'creado',
        );
      } else {
        _showMessage(
          'Error al guardar usuario: '
              '${_responseMessage(response)}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage('Error al guardar usuario: $e');
    }
  }

  Future<void> mostrarDialogCurso({CourseItem? course}) async {
    final isEditing = course != null;

    final nameController = TextEditingController(
      text: course?.name ?? '',
    );

    final acronymController = TextEditingController(
      text: course?.acronym ?? '',
    );

    final codeController = TextEditingController(
      text: course?.code ?? '',
    );

    final levelController = TextEditingController(
      text: course?.level?.toString() ?? '',
    );

    int? selectedCoordinatorUserId = course?.coordinatorUserId;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Editar ciclo' : 'Crear ciclo',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del ciclo',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'El nombre es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: acronymController,
                        decoration: const InputDecoration(
                          labelText: 'Acrónimo (ej. DAW)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'El acrónimo es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: 'Código (ej. 483)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'El código es obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: levelController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Nivel (1 o 2)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final level = int.tryParse(
                            value?.trim() ?? '',
                          );

                          if (level == null ||
                              level < 1 ||
                              level > 2) {
                            return 'El nivel debe ser 1 o 2';
                          }

                          return null;
                        },
                      ),

                      /*
                       * El coordinador solo se elige durante la edición.
                       * En creación se envía null y no se muestra este campo.
                       */
                      if (isEditing) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int?>(
                          value: selectedCoordinatorUserId,
                          decoration: const InputDecoration(
                            labelText: 'Coordinador (opcional)',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Sin coordinador'),
                            ),
                            ...users
                                .where(
                                  (user) =>
                              user.role.toUpperCase() ==
                                  'COORDINADOR',
                            )
                                .map(
                                  (user) => DropdownMenuItem<int?>(
                                value: user.id,
                                child: Text(user.username),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              selectedCoordinatorUserId = value;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    Navigator.of(dialogContext).pop(true);
                  },
                  child: Text(
                    isEditing ? 'Guardar' : 'Crear',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    final body = {
      'name': nameController.text.trim(),
      'acronym': acronymController.text.trim(),
      'code': codeController.text.trim(),
      'level': int.parse(levelController.text.trim()),
      'coordinatorUserId': isEditing
          ? selectedCoordinatorUserId
          : null,
    };

    try {
      final url = isEditing
          ? Uri.parse('${ApiConfig.courses}/${course!.id}')
          : Uri.parse(ApiConfig.courses);

      final response = isEditing
          ? await http.put(
        url,
        headers: requestHeaders,
        body: jsonEncode(body),
      )
          : await http.post(
        url,
        headers: requestHeaders,
        body: jsonEncode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        await cargarDatos();

        if (!mounted) return;

        _showMessage(
          isEditing
              ? 'Ciclo "${course.name}" actualizado'
              : 'Ciclo "${nameController.text.trim()}" creado',
        );
      } else {
        _showMessage(
          'Error al guardar ciclo: '
              '${_responseMessage(response)}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage('Error al guardar ciclo: $e');
    }
  }

  bool _isSuccess(http.Response response) {
    return response.statusCode == 200 ||
        response.statusCode == 204;
  }

  String _responseMessage(http.Response response) {
    final body = response.body.trim();

    if (body.isEmpty) {
      return 'Error HTTP ${response.statusCode}';
    }

    return body;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Administración de usuarios'),
        ),
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
          IconButton(
            tooltip: 'Crear ciclo',
            onPressed: () => mostrarDialogCurso(),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 1000) {
            return Column(
              children: [
                Expanded(
                  flex: 6,
                  child: _buildUsuariosSection(),
                ),
                const Divider(height: 1),
                Expanded(
                  flex: 4,
                  child: _buildCiclosSection(),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: _buildUsuariosSection(),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 4,
                child: _buildCiclosSection(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUsuariosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              const Text(
                'Usuarios del sistema',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${users.length} usuarios',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Añadir usuario',
                icon: const Icon(Icons.person_add_alt_1),
                onPressed: () => mostrarDialogUsuario(),
              ),
            ],
          ),
        ),
        Expanded(
          child: users.isEmpty
              ? const Center(
            child: Text(
              'No hay usuarios registrados',
              style: TextStyle(color: Colors.grey),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];

              final coursesText =
              user.coordinatorCourses.isEmpty
                  ? '-'
                  : user.coordinatorCourses
                  .map((course) => course.name)
                  .join(', ');

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                    accentColor.withOpacity(0.15),
                    child: Text(
                      user.username.isEmpty
                          ? '?'
                          : user.username
                          .substring(0, 1)
                          .toUpperCase(),
                      style: const TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    user.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getRoleColor(user.role)
                                  .withOpacity(0.15),
                              borderRadius:
                              BorderRadius.circular(12),
                            ),
                            child: Text(
                              user.role,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _getRoleColor(
                                  user.role,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              coursesText,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow:
                              TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(
                          Icons.edit,
                          size: 20,
                        ),
                        onPressed: () =>
                            mostrarDialogUsuario(
                              user: user,
                            ),
                      ),
                      IconButton(
                        tooltip: 'Resetear contraseña',
                        icon: const Icon(
                          Icons.lock_reset,
                          size: 20,
                        ),
                        onPressed: () =>
                            resetPassword(user),
                      ),
                      IconButton(
                        tooltip: 'Eliminar',
                        icon: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.red.shade700,
                        ),
                        onPressed: () =>
                            borrarUsuario(user),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCiclosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              const Text(
                'Ciclos actuales',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${courses.length} ciclos',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Añadir ciclo',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => mostrarDialogCurso(),
              ),
            ],
          ),
        ),
        Expanded(
          child: courses.isEmpty
              ? const Center(
            child: Text(
              'No hay ciclos registrados',
              style: TextStyle(color: Colors.grey),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            itemCount: courses.length,
            itemBuilder: (context, index) {
              final course = courses[index];

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                    accentColor.withOpacity(0.15),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    course.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'ID: ${course.id} · ${course.acronym} · '
                        'Nivel ${course.level ?? '-'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Editar ciclo',
                        icon: const Icon(
                          Icons.edit,
                          size: 20,
                        ),
                        onPressed: () =>
                            mostrarDialogCurso(
                              course: course,
                            ),
                      ),
                      IconButton(
                        tooltip: 'Eliminar ciclo',
                        icon: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.red.shade700,
                        ),
                        onPressed: () =>
                            borrarCurso(course),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return Colors.red.shade700;
      case 'ADMINISTRACION':
        return Colors.blue.shade700;
      case 'COORDINADOR':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
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

  final String? coordinatorDni;
  final String? coordinatorName;
  final String? coordinatorSurname;

  UserItem({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    required this.googleLinked,
    required this.authProvider,
    required this.coordinatorCourses,
    this.coordinatorDni,
    this.coordinatorName,
    this.coordinatorSurname,
  });

  factory UserItem.fromJson(Map<String, dynamic> json) {
    final coursesJson =
        json['coordinatorCourses'] as List? ?? [];

    return UserItem(
      id: _asInt(json['id']),
      username: (json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      googleLinked: json['googleLinked'] == true,
      authProvider: json['authProvider']?.toString(),
      coordinatorCourses: coursesJson
          .map(
            (item) => CourseItem.fromJson(
          item as Map<String, dynamic>,
        ),
      )
          .toList(),
      coordinatorDni: _readCoordinatorValue(
        json,
        'coordinatorDni',
      ),
      coordinatorName: _readCoordinatorValue(
        json,
        'coordinatorName',
      ),
      coordinatorSurname: _readCoordinatorValue(
        json,
        'coordinatorSurname',
      ),
    );
  }
}

class CourseItem {
  final int id;
  final String name;
  final String acronym;
  final String code;
  final int? level;
  final int? coordinatorUserId;

  CourseItem({
    required this.id,
    required this.name,
    required this.acronym,
    required this.code,
    this.level,
    this.coordinatorUserId,
  });

  factory CourseItem.fromJson(Map<String, dynamic> json) {
    return CourseItem(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      acronym: (json['acronym'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      level: _asNullableInt(json['level']),
      coordinatorUserId: _asNullableInt(
        json['coordinatorUserId'],
      ),
    );
  }
}

String? _readCoordinatorValue(
    Map<String, dynamic> json,
    String camelCaseKey,
    ) {
  final snakeCaseKey = _toSnakeCase(camelCaseKey);

  final value = json[camelCaseKey] ?? json[snakeCaseKey];

  if (value == null || value.toString().trim().isEmpty) {
    return null;
  }

  return value.toString();
}

String _toSnakeCase(String value) {
  return value.replaceAllMapped(
    RegExp(r'[A-Z]'),
        (match) => '_${match.group(0)!.toLowerCase()}',
  );
}

int _asInt(dynamic value) {
  if (value is int) return value;

  return int.tryParse(
    value?.toString() ?? '',
  ) ??
      0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;

  return int.tryParse(value.toString());
}