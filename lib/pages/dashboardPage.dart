import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:learnapp/main.dart';
import 'package:learnapp/pages/AnexosPage.dart';
import 'package:learnapp/pages/alumnosPage.dart';
import 'package:learnapp/pages/empresaPage.dart';
import 'package:learnapp/pages/loginPage.dart';
import 'package:learnapp/pages/practicasPage.dart';
import 'package:learnapp/pages/resultadosPage.dart';
import 'package:learnapp/pages/settingsPage.dart';
import 'package:learnapp/pages/tutoresPage.dart';
import 'package:learnapp/pages/userAdminPage.dart';

class ApiConfig {
  static const String baseUrl = 'https://learnback-c8vp.onrender.com';
  static const String apiPrefix = '/api';

  static String get authMe => '$baseUrl$apiPrefix/auth/me';
  static String get homeStudents => '$baseUrl$apiPrefix/home/students';
}

class Maindashboard extends StatefulWidget {
  const Maindashboard({super.key});

  @override
  State<Maindashboard> createState() => _MainPageState();
}

class _MainPageState extends State<Maindashboard> {
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();

  int selectedIndex = 0;
  String jwt = '';
  bool loading = true;
  String? errorMessage;

  String username = '';
  String email = '';
  String role = '';
  List<String> coordinatorCourses = [];
  List<HomeStudentItem> homeStudents = [];
  List<_DrawerItem> drawerItems = [];

  bool onlyPendingFilter = false;
  Set<String> selectedCourseFilters = {};

  int get assignedStudentsCount =>
      filteredStudents.where((s) => s.hasPractice).length;

  int get pendingStudentsCount =>
      filteredStudents.where((s) => !s.hasPractice).length;

  List<String> get availableCourses {
    final courses = homeStudents.map((s) => s.courseName).toSet().toList();
    courses.sort();
    return courses;
  }

  List<HomeStudentItem> get filteredStudents {
    return homeStudents.where((student) {
      final matchesPending = !onlyPendingFilter || !student.hasPractice;
      final matchesCourse = selectedCourseFilters.isEmpty ||
          selectedCourseFilters.contains(student.courseName);
      return matchesPending && matchesCourse;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    cargarDatosUsuario();
  }

  Future<void> cargarDatosUsuario() async {
    try {
      final token = await secureStorage.read(key: 'jwt');

      if (token == null || token.isEmpty) {
        setState(() {
          loading = false;
          errorMessage = 'No hay JWT guardado';
        });
        return;
      }

      final meUrl = Uri.parse(ApiConfig.authMe);
      final studentsUrl = Uri.parse(ApiConfig.homeStudents);

      final meResponse = await http.get(
        meUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('STATUS /me: ${meResponse.statusCode}');
      print('BODY /me: ${meResponse.body}');

      if (!mounted) return;

      if (meResponse.statusCode == 401) {
        await secureStorage.delete(key: 'jwt');
        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPageST()),
              (route) => false,
        );
        return;
      }

      if (meResponse.statusCode != 200) {
        setState(() {
          loading = false;
          errorMessage = 'No se pudo cargar la información del usuario';
        });
        return;
      }

      final meData = jsonDecode(meResponse.body);
      final loadedRole = (meData["role"] ?? '').toString();
      final dynamic rawCourses = meData["coordinatorCourses"];

      List<String> loadedCourses = [];

      if (rawCourses is List) {
        loadedCourses = rawCourses.map((course) {
          if (course is String) {
            return course;
          }
          if (course is Map<String, dynamic>) {
            return (course["name"] ?? course["nombre"] ?? '').toString();
          }
          if (course is Map) {
            return (course["name"] ?? course["nombre"] ?? '').toString();
          }
          return '';
        }).where((name) => name.isNotEmpty).toList();
      }

      final studentsResponse = await http.get(
        studentsUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('STATUS /api/home/students: ${studentsResponse.statusCode}');
      print('BODY /api/home/students: ${studentsResponse.body}');

      List<HomeStudentItem> loadedStudents = [];

      if (studentsResponse.statusCode == 200) {
        final decoded = jsonDecode(studentsResponse.body);

        if (decoded is List) {
          loadedStudents = decoded
              .map((item) => HomeStudentItem.fromJson(item))
              .toList();
        } else {
          print('La respuesta de /api/home/students no es una lista');
        }
      } else if (studentsResponse.statusCode == 401) {
        await secureStorage.delete(key: 'jwt');
        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPageST()),
              (route) => false,
        );
        return;
      } else {
        print('Error al cargar alumnos home: ${studentsResponse.body}');
      }

      if (!mounted) return;

      setState(() {
        jwt = token;
        username = (meData["username"] ?? '').toString();
        email = (meData["email"] ?? '').toString();
        role = loadedRole;
        coordinatorCourses = loadedCourses;
        homeStudents = loadedStudents;
        drawerItems = buildDrawerItems(loadedRole);
        loading = false;
      });
    } catch (e) {
      print('EXCEPCIÓN cargarDatosUsuario: $e');
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = 'Error cargando datos: $e';
      });
    }
  }

  List<_DrawerItem> buildDrawerItems(String role) {
    final bool isAdministracion =
        role == 'ADMINISTRACION' || role == 'ADMIN';
    final bool isCoordinador = role == 'COORDINADOR';

    final items = <_DrawerItem>[
      _DrawerItem(
        title: 'Inicio',
        icon: Icons.home,
        pageBuilder: (_) => _buildHomePage(),
      ),
    ];

    if (isAdministracion) {
      items.addAll([
        _DrawerItem(
          title: 'Alumnos',
          icon: Icons.person,
          pageBuilder: (_) => AlumnosPage(jwt: jwt),
        ),
        _DrawerItem(
          title: 'Resultados',
          icon: Icons.assessment,
          pageBuilder: (_) => ResultadosAprendizajePage(jwt: jwt),
        ),
        _DrawerItem(
          title: 'Empresas',
          icon: Icons.business,
          pageBuilder: (_) => EmpresasPage(jwt: jwt),
        ),
        _DrawerItem(
          title: 'Tutores',
          icon: Icons.people,
          pageBuilder: (_) => TutoresPage(jwt: jwt),
        ),
        _DrawerItem(
          title: 'Prácticas',
          icon: Icons.work_history,
          pageBuilder: (_) => PracticasPage(jwt: jwt),
        ),
        _DrawerItem(
          title: 'Anexos',
          icon: Icons.description,
          pageBuilder: (_) => AnexosEmpresasPage(jwt: jwt),
        ),
      ]);
    }

    if (isCoordinador) {
      items.addAll([
        _DrawerItem(
          title: 'Alumnos',
          icon: Icons.person,
          pageBuilder: (_) => AlumnosPage(jwt: jwt),
        ),
        _DrawerItem(
          title: 'Resultados',
          icon: Icons.assessment,
          pageBuilder: (_) => ResultadosAprendizajePage(jwt: jwt),
        ),
        _DrawerItem(
          title: 'Prácticas',
          icon: Icons.work_history,
          pageBuilder: (_) => PracticasPage(jwt: jwt),
        ),
        _DrawerItem(
          title: 'Anexos',
          icon: Icons.description,
          pageBuilder: (_) => AnexosEmpresasPage(jwt: jwt),
        ),
      ]);
    }

    return items;
  }

  void selectPage(int index) {
    setState(() {
      selectedIndex = index;
    });
    Navigator.pop(context);
  }

  Future<void> logout() async {
    await secureStorage.delete(key: 'jwt');

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPageST()),
          (route) => false,
    );
  }

  void toggleCourseFilter(String course) {
    setState(() {
      if (selectedCourseFilters.contains(course)) {
        selectedCourseFilters.remove(course);
      } else {
        selectedCourseFilters.add(course);
      }
    });
  }

  void clearFilters() {
    setState(() {
      onlyPendingFilter = false;
      selectedCourseFilters.clear();
    });
  }

  Color headerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF11141B)
        : const Color(0xFFF1F5F9);
  }

  Widget _buildHomePage() {
    final bool isCoordinador = role == 'COORDINADOR';
    final bool isMobile = MediaQuery.of(context).size.width < 1000;

    final studentsSection = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCoordinador ? 'Alumnos de tus ciclos' : 'Todos los alumnos',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilterChip(
                label: const Text('Solo sin prácticas'),
                selected: onlyPendingFilter,
                onSelected: (value) {
                  setState(() {
                    onlyPendingFilter = value;
                  });
                },
                avatar: Icon(
                  Icons.pending_actions_rounded,
                  size: 18,
                  color: onlyPendingFilter ? Colors.orange.shade800 : null,
                ),
              ),
              if (selectedCourseFilters.isNotEmpty || onlyPendingFilter)
                OutlinedButton.icon(
                  onPressed: clearFilters,
                  icon: const Icon(Icons.clear),
                  label: const Text('Limpiar filtros'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (availableCourses.isNotEmpty) ...[
            const Text(
              'Filtrar por ciclo',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: availableCourses.map((course) {
                final selected = selectedCourseFilters.contains(course);
                return FilterChip(
                  label: Text(course),
                  selected: selected,
                  onSelected: (_) => toggleCourseFilter(course),
                  selectedColor: Colors.blue.withOpacity(0.15),
                  checkmarkColor: Colors.blue.shade700,
                  side: BorderSide(
                    color: selected
                        ? Colors.blue.withOpacity(0.35)
                        : Colors.grey.withOpacity(0.25),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
          ],
          Text(
            'Mostrando ${filteredStudents.length} alumnos',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (filteredStudents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No hay alumnos que coincidan con los filtros'),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 52,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 64,
                columns: const [
                  DataColumn(label: Text('Alumno')),
                  DataColumn(label: Text('Curso')),
                  DataColumn(label: Text('Prácticas')),
                  DataColumn(label: Text('Empresa')),
                ],
                rows: filteredStudents.map((student) {
                  return DataRow(
                    cells: [
                      DataCell(Text(student.fullName)),
                      DataCell(Text(student.courseName)),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: student.hasPractice
                                ? Colors.green.withOpacity(0.15)
                                : Colors.orange.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            student.hasPractice ? 'Sí' : 'Pendiente',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: student.hasPractice
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(student.companyName ?? '-')),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );

    final summarySection = Column(
      children: [
        _buildStatCard(
          title: 'Total visibles',
          value: filteredStudents.length.toString(),
          icon: Icons.groups_rounded,
          color: Colors.blue,
        ),
        const SizedBox(height: 16),
        _buildStatCard(
          title: 'Asignados',
          value: assignedStudentsCount.toString(),
          icon: Icons.check_circle_rounded,
          color: Colors.green,
        ),
        const SizedBox(height: 16),
        _buildStatCard(
          title: 'Pendientes',
          value: pendingStudentsCount.toString(),
          icon: Icons.pending_actions_rounded,
          color: Colors.orange,
        ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Datos del usuario',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _infoRow('Nombre', username),
                const SizedBox(height: 8),
                _infoRow('Correo', email),
                const SizedBox(height: 8),
                _infoRow('Rol', role),
                if (isCoordinador) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Cursos coordinados',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  if (coordinatorCourses.isEmpty)
                    const Text('No tiene cursos asignados')
                  else
                    ...coordinatorCourses.map(
                          (course) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.school, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(course)),
                          ],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (isMobile)
            Column(
              children: [
                studentsSection,
                const SizedBox(height: 20),
                summarySection,
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: studentsSection,
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 4,
                  child: summarySection,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.18),
            color.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: color.withOpacity(0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(0.18),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(value.isEmpty ? '-' : value),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool canManageCenterInfo =
        role == 'ADMINISTRACION' || role == 'ADMIN';
    final bool isAdmin = role == 'ADMIN';

    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inicio')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inicio')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              errorMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (drawerItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inicio')),
        body: const Center(
          child: Text('No hay módulos disponibles para este usuario'),
        ),
      );
    }

    final currentTitle = drawerItems[selectedIndex].title;
    final currentPage = drawerItems[selectedIndex].pageBuilder(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(currentTitle),
        actions: [
          if (isAdmin)
            IconButton(
              tooltip: 'Administrar usuarios',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => UsersAdminPage(jwt: jwt),
                  ),
                );
              },
              icon: const Icon(Icons.admin_panel_settings_outlined),
            ),
          IconButton(
            tooltip: canManageCenterInfo
                ? 'Configuración general'
                : 'Solo administración puede acceder a esta opción',
            onPressed: canManageCenterInfo
                ? () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => InfoCoursePage(jwt: jwt),
                ),
              );
            }
                : null,
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            onPressed: () {
              MyApp.of(context).toggleTheme();
            },
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: 'cerrar sesión',
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Theme.of(context).drawerTheme.backgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: headerColor(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 28,
                    child: Icon(Icons.person, color: Colors.black, size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    username.isEmpty ? 'Usuario' : username,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email.isEmpty ? '-' : email,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black54,
                    ),
                  ),

                ],
              ),
            ),
            ...List.generate(drawerItems.length, (index) {
              final item = drawerItems[index];
              return ListTile(
                leading: Icon(item.icon),
                title: Text(item.title),
                selected: selectedIndex == index,
                onTap: () => selectPage(index),
              );
            }),
          ],
        ),
      ),
      body: currentPage,
    );
  }
}

class _DrawerItem {
  final String title;
  final IconData icon;
  final Widget Function(BuildContext context) pageBuilder;

  _DrawerItem({
    required this.title,
    required this.icon,
    required this.pageBuilder,
  });
}

class HomeStudentItem {
  final int id;
  final String fullName;
  final String courseName;
  final bool hasPractice;
  final String? companyName;

  HomeStudentItem({
    required this.id,
    required this.fullName,
    required this.courseName,
    required this.hasPractice,
    required this.companyName,
  });

  factory HomeStudentItem.fromJson(Map<String, dynamic> json) {
    return HomeStudentItem(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      fullName: (json['fullName'] ?? '').toString(),
      courseName: (json['courseName'] ?? '').toString(),
      hasPractice: json['hasPractice'] == true,
      companyName: json['companyName']?.toString(),
    );
  }
}