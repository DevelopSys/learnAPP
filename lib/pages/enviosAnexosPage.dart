import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

const Color accentColor = Color(0xFF3ECF8E);

class EnvioPracticasPage extends StatefulWidget {
  final String jwt;

  const EnvioPracticasPage({super.key, required this.jwt});

  @override
  State<EnvioPracticasPage> createState() => _EnvioPracticasPageState();
}

class _EnvioPracticasPageState extends State<EnvioPracticasPage> {
  final String baseUrl = 'http://localhost:8080';
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
      'https://www.googleapis.com/auth/gmail.send',
    ],
    clientId: 'TU_CLIENT_ID.apps.googleusercontent.com', // RECUERDA CAMBIAR ESTO
  );

  List<dynamic> practices = [];
  bool loading = true;
  String? errorMsg;

  // --- VARIABLES PARA FILTROS ---
  List<String> _courses = [];
  String? _selectedCourse;
  final TextEditingController _companyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _companyController.addListener(() {
      setState(() {});
    });
    _cargarPracticas();
  }

  @override
  void dispose() {
    _companyController.dispose();
    super.dispose();
  }

  Future<String?> _getGoogleAccessToken() async {
    try {
      await _googleSignIn.signInSilently();
      final account = _googleSignIn.currentUser;
      if (account == null) return null;
      final auth = await account.authentication;
      return auth.accessToken;
    } catch (e) {
      return null;
    }
  }

  Future<void> _cargarPracticas() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/practices'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwt}',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        setState(() {
          practices = data;

          _courses = practices
              .map((p) => _getCourse(p))
              .where((c) => c != 'Sin curso')
              .toSet()
              .toList()
            ..sort();

          loading = false;
        });
      } else {
        setState(() {
          errorMsg = 'Error al cargar prácticas: ${response.statusCode}';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = 'Error de conexión: $e';
        loading = false;
      });
    }
  }

  List<dynamic> get _filteredPractices {
    return practices.where((p) {
      final matchesCourse = _selectedCourse == null || _getCourse(p) == _selectedCourse;
      final matchesCompany = _companyController.text.isEmpty ||
          _getEmpresa(p).toLowerCase().contains(_companyController.text.toLowerCase());
      return matchesCourse && matchesCompany;
    }).toList();
  }

  // --- NUEVO: Obtiene todos los nombres separados por comas ---
  String _getNombresAlumnos(dynamic practice) {
    final students = practice['students'] as List?;
    if (students == null || students.isEmpty) return 'Sin alumnos';
    return students
        .map((s) => '${s['firstName'] ?? ''} ${s['lastName'] ?? ''}'.trim())
        .join(', ');
  }

  String _getCourse(dynamic practice) {
    try {
      final students = practice['students'] as List?;
      if (students != null && students.isNotEmpty) {
        return students[0]['course']?['name'] ?? 'Sin curso';
      }
    } catch (_) {}
    return 'Sin curso';
  }

  String _getEmailTutor(dynamic practice) {
    if (practice['trainee'] != null) {
      if (practice['trainee'] is Map) {
        return practice['trainee']['email'] ?? 'Sin email';
      }
    }
    if (practice['traineeEmail'] != null) {
      return practice['traineeEmail'];
    }
    return 'Sin email';
  }

  String _getEmpresa(dynamic practice) {
    if (practice['company'] != null) {
      if (practice['company'] is String) {
        return practice['company'];
      }
      if (practice['company'] is Map) {
        return practice['company']['legalName'] ??
            practice['company']['legal'] ??
            practice['company']['businessName'] ??
            'Sin nombre de empresa';
      }
    }
    if (practice['companyName'] != null) {
      return practice['companyName'];
    }
    return 'Sin empresa';
  }

  Future<void> _mostrarDialogoEnvio(dynamic practice) async {
    final students = practice['students'] as List? ?? [];
    final bool variosAlumnos = students.length > 1;
    final String textoAlumnos = variosAlumnos
        ? 'de los alumnos ${_getNombresAlumnos(practice)}'
        : 'del alumno/a ${_getNombresAlumnos(practice)}';

    final cuerpoController = TextEditingController(
      text:
      'Estimado/a tutor/a,\n\nAdjunto los anexos correspondientes a las prácticas $textoAlumnos.\n\nQuedo a su disposición para cualquier consulta.\n\nUn saludo.',
    );

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar anexos'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF111720)
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📋 Práctica ${practice['id']} - ${_getCourse(practice)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('👥 Alumno(s): ${_getNombresAlumnos(practice)}'),
                    Text('🏢 Empresa: ${_getEmpresa(practice)}'),
                    Text('📧 Tutor: ${_getEmailTutor(practice)}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Cuerpo del correo:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: cuerpoController,
                maxLines: 6,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  hintText: 'Escribe el mensaje...',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.attach_file, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      variosAlumnos
                          ? 'Se adjuntarán: Anexos 4, 6, 8 y 9 por cada alumno.'
                          : 'Se adjuntarán: Anexo 4, Anexo 6, Anexo 8 y Anexo 9.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send),
            label: const Text('Enviar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _enviarAnexos(practice['id'], cuerpoController.text);
    }
  }

  // --- YA NO RECIBE EL studentId ---
  Future<void> _enviarAnexos(int practiceId, String cuerpo) async {
    final accessToken = await _getGoogleAccessToken();
    if (accessToken == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Necesitas iniciar sesión con Google para enviar emails'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: accentColor),
            SizedBox(height: 16),
            Text('Generando y enviando anexos...',
                style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );

    try {
      // --- YA NO MANDAMOS EL studentId AL BACKEND ---
      final body = {
        'cuerpo': cuerpo,
        'accessToken': accessToken,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/api/practices/$practiceId/send-anexos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.jwt}',
        },
        body: jsonEncode(body),
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Email enviado a ${data['emailEnviado']}'),
            backgroundColor: accentColor,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${response.body}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error de red: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: accentColor),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Envío de Anexos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarPracticas,
            tooltip: 'Recargar prácticas',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (errorMsg != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(errorMsg!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarPracticas,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (practices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('No hay prácticas disponibles',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    final displayedPractices = _filteredPractices;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Envío de documentos al tutor',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selecciona una práctica para enviar los Anexos 4, 6, 8 y 9 directamente al correo del tutor de empresa.',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.68)
                      : Colors.black.withOpacity(0.60),
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E2532)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF263041)
                        : const Color(0xFFD7DEE8),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _companyController,
                        decoration: InputDecoration(
                          labelText: 'Buscar por empresa',
                          prefixIcon: const Icon(Icons.business_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        value: _selectedCourse,
                        decoration: InputDecoration(
                          labelText: 'Filtrar por curso',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Todos los cursos'),
                          ),
                          ..._courses.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedCourse = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (displayedPractices.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No hay prácticas que coincidan con los filtros.',
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayedPractices.length,
                  itemBuilder: (context, index) {
                    final practice = displayedPractices[index];
                    final emailTutor = _getEmailTutor(practice);
                    final tieneEmail = emailTutor != 'Sin email' &&
                        emailTutor.trim().isNotEmpty;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF263041)
                              : const Color(0xFFD7DEE8),
                        ),
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.assignment_ind_outlined,
                                  color: accentColor),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Práctica #${practice['id']} - ${_getCourse(practice)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  // --- AQUÍ AHORA MOSTRAMOS TODOS LOS NOMBRES ---
                                  Text('👥 ${_getNombresAlumnos(practice)}'),

                                  InkWell(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('JSON de la Práctica'),
                                          content: SizedBox(
                                            width: double.maxFinite,
                                            height: 400,
                                            child: SingleChildScrollView(
                                              child: Text(
                                                const JsonEncoder.withIndent('  ').convert(practice),
                                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                              ),
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text('Cerrar'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('🏢 ${_getEmpresa(practice)}'),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.bug_report, size: 16, color: Colors.grey),
                                      ],
                                    ),
                                  ),

                                  Text(
                                    '📧 Tutor: $emailTutor',
                                    style: TextStyle(
                                      color: tieneEmail
                                          ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                          ? Colors.white70
                                          : Colors.black54)
                                          : Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: tieneEmail
                                  ? () => _mostrarDialogoEnvio(practice)
                                  : null,
                              icon: const Icon(Icons.send_outlined, size: 18),
                              label: const Text('Enviar anexos'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}