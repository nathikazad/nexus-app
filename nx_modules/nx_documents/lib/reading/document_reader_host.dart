import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nx_documents/documents/document_content.dart';
import 'package:nx_documents/reading/document_reader.dart';

class DocumentReaderHost extends StatefulWidget {
  const DocumentReaderHost({
    required this.identity,
    required this.repository,
    this.imageUrlResolver,
    this.onOpenLink,
    this.textScaleFactor = 1,
    super.key,
  });

  final DocumentIdentity identity;
  final DocumentContentRepository repository;
  final String Function(String url)? imageUrlResolver;
  final Future<bool> Function(String href)? onOpenLink;
  final double textScaleFactor;

  @override
  State<DocumentReaderHost> createState() => _DocumentReaderHostState();
}

class _DocumentReaderHostState extends State<DocumentReaderHost> {
  DocumentContent? _content;
  Object? _loadError;
  Object? _saveError;
  var _hasLoaded = false;
  Future<void> _saveChain = Future<void>.value();
  var _loadGeneration = 0;
  var _contentRevision = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant DocumentReaderHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity ||
        oldWidget.repository != widget.repository) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    setState(() {
      _content = null;
      _hasLoaded = false;
      _loadError = null;
      _saveError = null;
    });
    try {
      final content = await widget.repository.load(widget.identity);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _content = content;
        _hasLoaded = true;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _loadError = error);
    }
  }

  Future<void> _save(DocumentContent content) {
    final revision = ++_contentRevision;
    setState(() {
      _content = content;
      _saveError = null;
    });
    final save = _saveChain
        .catchError((_) {})
        .then((_) async {
          final saved = await widget.repository.save(content);
          if (!mounted ||
              revision != _contentRevision ||
              _content?.identity != saved.identity) {
            return;
          }
          setState(() => _content = saved);
        })
        .catchError((Object error) {
          if (mounted) setState(() => _saveError = error);
        });
    _saveChain = save;
    return save;
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    if (_loadError != null) {
      return _ReaderMessage(
        message: 'Could not open notes: $_loadError',
        onRetry: _load,
      );
    }
    if (content == null) {
      if (_hasLoaded) {
        return _ReaderMessage(
          message: 'No notes were found for this document.',
          onRetry: _load,
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: DocumentReader(
            content: content,
            onChanged: _save,
            imageUrlResolver: widget.imageUrlResolver,
            onOpenLink: widget.onOpenLink,
            textScaleFactor: widget.textScaleFactor,
          ),
        ),
        if (_saveError != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text('Highlight was not saved: $_saveError'),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReaderMessage extends StatelessWidget {
  const _ReaderMessage({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
