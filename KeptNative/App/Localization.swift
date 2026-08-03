// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Kavaju

import Foundation

struct Copy {
    let language: String
    var isSpanish: Bool { language == "es" }
    var chat: String { isSpanish ? "Chat" : "Chat" }
    var memory: String { isSpanish ? "Memorias" : "Memories" }
    var tasks: String { isSpanish ? "Tareas" : "Tasks" }
    var placeholder: String { isSpanish ? "Escribe algo para recordar…" : "Write something to remember…" }
    var translationPlaceholder: String { isSpanish ? "Escribe el texto que quieres traducir…" : "Write the text you want to translate…" }
    var translationMode: String { isSpanish ? "Modo traducción" : "Translation mode" }
    var translating: String { isSpanish ? "Traduciendo…" : "Translating…" }
    var sourceLanguage: String { isSpanish ? "Idioma de origen" : "Source language" }
    var targetLanguage: String { isSpanish ? "Idioma de salida" : "Target language" }
    var textStyle: String { isSpanish ? "Estilo de texto" : "Text style" }
    var exitTranslation: String { isSpanish ? "Salir del modo traducción" : "Exit translation mode" }
    var copyTranslation: String { isSpanish ? "Copiar traducción" : "Copy translation" }
    var noMessages: String { isSpanish ? "Cuéntame qué necesitas recordar." : "Tell me what you need to remember." }
    var noTasks: String { isSpanish ? "No hay tareas pendientes" : "No pending tasks" }
    var noMemories: String { isSpanish ? "Aún no hay recuerdos" : "No memories yet" }
    var noTimelineItems: String { isSpanish ? "No hay tareas pendientes ni recuerdos" : "No pending tasks or memories" }
    var pending: String { isSpanish ? "Pendientes" : "Pending" }
    var completed: String { isSpanish ? "Completadas" : "Completed" }
    var cancel: String { isSpanish ? "Cancelar" : "Cancel" }
    var confirm: String { isSpanish ? "Continuar" : "Continue" }
    var save: String { isSpanish ? "Guardar" : "Save" }
    var addTask: String { isSpanish ? "Nueva tarea" : "New task" }
    var settings: String { isSpanish ? "Ajustes" : "Settings" }
    var memoriesSubtitle: String { isSpanish ? "Tu agenda y lo que importa" : "Your agenda and what matters" }
    var overdue: String { isSpanish ? "Atrasadas" : "Overdue" }
    var today: String { isSpanish ? "Hoy" : "Today" }
    var upcoming: String { isSpanish ? "Próximamente" : "Upcoming" }
    var previous: String { isSpanish ? "Anteriores" : "Previous" }
    var hideCompleted: String { isSpanish ? "Ocultar completadas" : "Hide completed" }
    var showCompleted: String { isSpanish ? "Mostrar completadas" : "Show completed" }
    var pendingSummary: String { isSpanish ? "pendientes" : "pending" }
    var memoriesSummary: String { isSpanish ? "recuerdos" : "memories" }
    var edit: String { isSpanish ? "Editar" : "Edit" }
    var delete: String { isSpanish ? "Eliminar" : "Delete" }
    var deleteTask: String { isSpanish ? "Eliminar tarea" : "Delete task" }
    var deleteMemory: String { isSpanish ? "Eliminar recuerdo" : "Delete memory" }
    var task: String { isSpanish ? "Tarea" : "Task" }
    var editTask: String { isSpanish ? "Editar tarea" : "Edit task" }
    var dateAndTime: String { isSpanish ? "Fecha y hora" : "Date and time" }
    var recurrence: String { isSpanish ? "Repetición" : "Recurrence" }
    var interval: String { isSpanish ? "Cada" : "Every" }
    var alert: String { isSpanish ? "Avisar" : "Alert" }
    var atEventTime: String { isSpanish ? "A la hora del evento" : "At event time" }
    var before: String { isSpanish ? "antes" : "before" }
    var weeklyDays: String { isSpanish ? "Días de la semana" : "Weekdays" }
    var monthDay: String { isSpanish ? "Día del mes" : "Day of month" }
    var title: String { isSpanish ? "Título" : "Title" }
    var originalText: String { isSpanish ? "Texto original" : "Original text" }
    var category: String { isSpanish ? "Categoría" : "Category" }

    func recurrenceName(_ value: RecurrenceFrequency) -> String {
        switch value {
        case .none: isSpanish ? "No se repite" : "Does not repeat"
        case .daily: isSpanish ? "Diaria" : "Daily"
        case .weekly: isSpanish ? "Semanal" : "Weekly"
        case .monthly: isSpanish ? "Mensual" : "Monthly"
        case .yearly: isSpanish ? "Anual" : "Yearly"
        }
    }

    func leadUnitName(_ value: LeadUnit, plural: Bool = false) -> String {
        switch value {
        case .minute: isSpanish ? (plural ? "minutos" : "minuto") : (plural ? "minutes" : "minute")
        case .hour: isSpanish ? (plural ? "horas" : "hora") : (plural ? "hours" : "hour")
        case .day: isSpanish ? (plural ? "días" : "día") : (plural ? "days" : "day")
        case .week: isSpanish ? (plural ? "semanas" : "semana") : (plural ? "weeks" : "week")
        case .month: isSpanish ? (plural ? "meses" : "mes") : (plural ? "months" : "month")
        }
    }
}

@MainActor
func resolvedCopy(_ settings: AppSettings) -> Copy {
    let language: String
    if settings.interfaceLanguage == "es" || settings.interfaceLanguage == "en" {
        language = settings.interfaceLanguage
    } else {
        language = Locale.current.language.languageCode?.identifier == "es" ? "es" : "en"
    }
    return Copy(language: language)
}
