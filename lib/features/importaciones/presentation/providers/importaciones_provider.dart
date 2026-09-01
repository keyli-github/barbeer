import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/providers/sede_scope_provider.dart';
import '../../data/excel_import_file_picker.dart';
import '../../data/importaciones_repository.dart';
import '../../data/models/importacion_models.dart';

enum ImportOperationStatus { idle, loading, success, error }

const _unset = Object();

class ImportacionesState {
  final List<ImportVenue> venues;
  final bool venuesLoading;
  final String? venuesError;
  final String selectedVenueId;
  final ExcelImportFile? selectedFile;
  final bool pickerBusy;
  final String? fileError;
  final ImportOperationStatus previewStatus;
  final ExcelImportPreview? preview;
  final String? previewError;
  final bool confirmed;
  final ImportOperationStatus importStatus;
  final ExcelImportResult? result;
  final String? importError;

  const ImportacionesState({
    this.venues = const [],
    this.venuesLoading = false,
    this.venuesError,
    this.selectedVenueId = '',
    this.selectedFile,
    this.pickerBusy = false,
    this.fileError,
    this.previewStatus = ImportOperationStatus.idle,
    this.preview,
    this.previewError,
    this.confirmed = false,
    this.importStatus = ImportOperationStatus.idle,
    this.result,
    this.importError,
  });

  bool get isBusy =>
      pickerBusy ||
      previewStatus == ImportOperationStatus.loading ||
      importStatus == ImportOperationStatus.loading;

  bool get canPreview =>
      selectedVenueId.isNotEmpty && selectedFile != null && !isBusy;

  bool get canSubmit =>
      selectedVenueId.isNotEmpty &&
      selectedFile != null &&
      confirmed &&
      previewStatus == ImportOperationStatus.success &&
      preview?.duplicate == null &&
      (importStatus == ImportOperationStatus.idle ||
          importStatus == ImportOperationStatus.error);

  ImportacionesState copyWith({
    List<ImportVenue>? venues,
    bool? venuesLoading,
    Object? venuesError = _unset,
    String? selectedVenueId,
    Object? selectedFile = _unset,
    bool? pickerBusy,
    Object? fileError = _unset,
    ImportOperationStatus? previewStatus,
    Object? preview = _unset,
    Object? previewError = _unset,
    bool? confirmed,
    ImportOperationStatus? importStatus,
    Object? result = _unset,
    Object? importError = _unset,
  }) => ImportacionesState(
    venues: venues ?? this.venues,
    venuesLoading: venuesLoading ?? this.venuesLoading,
    venuesError: venuesError == _unset
        ? this.venuesError
        : venuesError as String?,
    selectedVenueId: selectedVenueId ?? this.selectedVenueId,
    selectedFile: selectedFile == _unset
        ? this.selectedFile
        : selectedFile as ExcelImportFile?,
    pickerBusy: pickerBusy ?? this.pickerBusy,
    fileError: fileError == _unset ? this.fileError : fileError as String?,
    previewStatus: previewStatus ?? this.previewStatus,
    preview: preview == _unset ? this.preview : preview as ExcelImportPreview?,
    previewError: previewError == _unset
        ? this.previewError
        : previewError as String?,
    confirmed: confirmed ?? this.confirmed,
    importStatus: importStatus ?? this.importStatus,
    result: result == _unset ? this.result : result as ExcelImportResult?,
    importError: importError == _unset
        ? this.importError
        : importError as String?,
  );
}

class ImportacionesNotifier extends StateNotifier<ImportacionesState> {
  final ImportacionesRepository _repository;
  final ExcelImportFilePicker _picker;

  ImportacionesNotifier(
    this._repository,
    this._picker, {
    String? initialVenueId,
  }) : super(ImportacionesState(selectedVenueId: initialVenueId?.trim() ?? ''));

  Future<void> loadVenues() async {
    if (state.venuesLoading) return;
    state = state.copyWith(venuesLoading: true, venuesError: null);
    try {
      final venues = await _repository.listVenues();
      if (!mounted) return;
      final selectedStillExists =
          state.selectedVenueId.isEmpty ||
          venues.any((venue) => venue.id == state.selectedVenueId);
      state = state.copyWith(
        venues: venues,
        venuesLoading: false,
        venuesError: null,
        selectedVenueId: selectedStillExists ? state.selectedVenueId : '',
        previewStatus: selectedStillExists
            ? state.previewStatus
            : ImportOperationStatus.idle,
        preview: selectedStillExists ? state.preview : null,
        previewError: selectedStillExists ? state.previewError : null,
        confirmed: selectedStillExists ? state.confirmed : false,
        importStatus: selectedStillExists
            ? state.importStatus
            : ImportOperationStatus.idle,
        result: selectedStillExists ? state.result : null,
        importError: selectedStillExists ? state.importError : null,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        venuesLoading: false,
        venuesError: _message(error, 'No se pudieron cargar las sedes.'),
      );
    }
  }

  void selectVenue(String? venueId) {
    final normalized = venueId?.trim() ?? '';
    if (state.isBusy || normalized == state.selectedVenueId) return;
    state = _resetFlow(
      state.copyWith(selectedVenueId: normalized),
      keepFileError: true,
    );
  }

  Future<void> pickFile() async {
    if (state.isBusy) return;
    state = state.copyWith(pickerBusy: true, fileError: null);
    try {
      final selected = await _picker.pick();
      if (selected == null) {
        state = state.copyWith(pickerBusy: false);
        return;
      }
      setFile(selected);
    } catch (error) {
      state = _resetFlow(
        state.copyWith(
          selectedFile: null,
          pickerBusy: false,
          fileError: _message(error, 'No se pudo seleccionar el archivo.'),
        ),
        keepFileError: true,
      );
    }
  }

  void setFile(ExcelImportFile? file) {
    if (state.previewStatus == ImportOperationStatus.loading ||
        state.importStatus == ImportOperationStatus.loading) {
      return;
    }
    state = _resetFlow(
      state.copyWith(selectedFile: file, pickerBusy: false, fileError: null),
      keepFileError: true,
    );
  }

  Future<void> previewExcel() async {
    if (!state.canPreview) return;
    final file = state.selectedFile!;
    final venueId = state.selectedVenueId;
    state = state.copyWith(
      previewStatus: ImportOperationStatus.loading,
      preview: null,
      previewError: null,
      confirmed: false,
      importStatus: ImportOperationStatus.idle,
      result: null,
      importError: null,
    );
    try {
      final preview = await _repository.previewExcel(file, venueId);
      if (!mounted) return;
      state = state.copyWith(
        previewStatus: ImportOperationStatus.success,
        preview: preview,
        previewError: null,
        confirmed: false,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        previewStatus: ImportOperationStatus.error,
        preview: null,
        previewError: _message(error, 'No se pudo previsualizar el Excel.'),
        confirmed: false,
      );
    }
  }

  void setConfirmed(bool value) {
    if (state.importStatus == ImportOperationStatus.loading ||
        state.importStatus == ImportOperationStatus.success ||
        state.previewStatus != ImportOperationStatus.success ||
        state.preview?.duplicate != null) {
      return;
    }
    state = state.copyWith(confirmed: value);
  }

  Future<void> importExcel() async {
    if (!state.canSubmit) return;
    final file = state.selectedFile!;
    final venueId = state.selectedVenueId;
    state = state.copyWith(
      importStatus: ImportOperationStatus.loading,
      result: null,
      importError: null,
    );
    try {
      final result = await _repository.importExcel(file, venueId);
      if (!mounted) return;
      state = state.copyWith(
        importStatus: ImportOperationStatus.success,
        result: result,
        importError: null,
        confirmed: false,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        importStatus: ImportOperationStatus.error,
        result: null,
        importError: _message(error, 'No se pudo completar la importación.'),
      );
    }
  }

  ImportacionesState _resetFlow(
    ImportacionesState current, {
    required bool keepFileError,
  }) => current.copyWith(
    fileError: keepFileError ? current.fileError : null,
    previewStatus: ImportOperationStatus.idle,
    preview: null,
    previewError: null,
    confirmed: false,
    importStatus: ImportOperationStatus.idle,
    result: null,
    importError: null,
  );

  String _message(Object error, String fallback) {
    if (error is AppException && error.message.isNotEmpty) return error.message;
    if (error is ExcelImportFileException) return error.message;
    if (error is FormatException && error.message.isNotEmpty) {
      return error.message;
    }
    return fallback;
  }
}

final importacionesRepositoryProvider = Provider<ImportacionesRepository>(
  (_) => ImportacionesRepository(ApiClient.instance),
);

final excelImportFilePickerProvider = Provider<ExcelImportFilePicker>(
  (_) => const SystemExcelImportFilePicker(),
);

final importacionesProvider =
    StateNotifierProvider.autoDispose<
      ImportacionesNotifier,
      ImportacionesState
    >((ref) {
      final notifier = ImportacionesNotifier(
        ref.watch(importacionesRepositoryProvider),
        ref.watch(excelImportFilePickerProvider),
        initialVenueId: ref.watch(globalSedeIdProvider),
      );
      Future.microtask(notifier.loadVenues);
      return notifier;
    });
