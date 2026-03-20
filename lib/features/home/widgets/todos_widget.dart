/// To-do list widget for the home screen.
///
/// Displays a scrollable checklist with an add button in the header.
/// Each item can be toggled between done/undone states.
import 'package:flutter/material.dart';
import 'package:myapp/models/todo_item.dart';

class TodosWidget extends StatelessWidget {
  /// Current list of to-do items.
  final List<TodoItem> todos;

  /// Called when the "+" button is tapped to show the add-todo dialog.
  final VoidCallback onAddTodoTap;

  /// Called when a to-do item's checkbox is toggled, with its index.
  final ValueChanged<int> onToggleTodo;

  const TodosWidget({
    super.key,
    required this.todos,
    required this.onAddTodoTap,
    required this.onToggleTodo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and add button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text('To-Do List',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16)),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: Colors.white70),
                onPressed: onAddTodoTap,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Task list or empty state
          Expanded(
            child: todos.isEmpty
                ? const Center(
                    child: Text('No tasks yet.',
                        style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: todos.length,
                    itemBuilder: (context, index) {
                      final todo = todos[index];
                      return CheckboxListTile(
                        value: todo.isDone,
                        onChanged: (_) => onToggleTodo(index),
                        title: Text(
                          todo.task,
                          style: TextStyle(
                            color:
                                todo.isDone ? Colors.white54 : Colors.white,
                            decoration: todo.isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Colors.white,
                        checkColor: Colors.black,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
