import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';

class TodoListPage extends StatefulWidget {
  final String category;

  const TodoListPage({
    super.key,
    required this.category,
  });

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  final TextEditingController todoController = TextEditingController();

  final user = FirebaseAuth.instance.currentUser;
  final CollectionReference todoRef =
      FirebaseFirestore.instance.collection('todos');

  // ================= CREATE =================
  Future<void> addTodo() async {
    if (todoController.text.trim().isEmpty) return;

    await todoRef.add({
      'title': todoController.text.trim(),
      'uid': user!.uid,
      'category': widget.category, // 🔥 INI KUNCI
      'isDone': false,
      'createdAt': Timestamp.now(),
    });

    todoController.clear();
  }

  // ================= DELETE =================
  Future<void> deleteTodo(String id) async {
    await todoRef.doc(id).delete();
  }

  // ================= UPDATE =================
  Future<void> editTodo(String id, String oldTitle) async {
    final TextEditingController editController =
        TextEditingController(text: oldTitle);

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Edit Todo'),
          content: TextField(
            controller: editController,
            decoration: const InputDecoration(
              hintText: 'Edit todo...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (editController.text.trim().isEmpty) return;

                await todoRef.doc(id).update({
                  'title': editController.text.trim(),
                });

                Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  // ================= TOGGLE CHECKBOX =================
  Future<void> toggleTodo(String id, bool value) async {
    await todoRef.doc(id).update({
      'isDone': value,
    });
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
          ),
        ],
      ),
      body: Column(
        children: [
          // INPUT TODO
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: todoController,
                    decoration: const InputDecoration(
                      hintText: 'Tambah todo...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.add, size: 30),
                  onPressed: addTodo,
                ),
              ],
            ),
          ),

          // LIST TODO
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: todoRef
                  .where('uid', isEqualTo: user!.uid)
                  .where('category', isEqualTo: widget.category)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Terjadi error'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return const Center(child: Text('Belum ada todo'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: ListTile(
                        leading: Checkbox(
                          value: data['isDone'] ?? false,
                          onChanged: (value) {
                            toggleTodo(data.id, value!);
                          },
                        ),
                        title: Text(
                          data['title'],
                          style: TextStyle(
                            decoration: data['isDone'] == true
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: data['isDone'] == true
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => editTodo(data.id, data['title']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => deleteTodo(data.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
