type t = {
  id: int,
  question: string,
  answerOptions: list(CurriculumEditor__AnswerOption.t),
};

let id = t => t.id;

let question = t => t.question;

let answerOptions = t => t.answerOptions;

let empty = id => {
  id,
  question: "",
  answerOptions: [
    CurriculumEditor__AnswerOption.empty(0),
    CurriculumEditor__AnswerOption.empty(1)
    |> CurriculumEditor__AnswerOption.markAsCorrect,
  ],
};

let updateQuestion = (question, t) => {...t, question};

let newAnswerOption = (id, t) => {
  let answerOption = CurriculumEditor__AnswerOption.empty(id);
  let newAnswerOptions =
    t.answerOptions |> List.rev |> List.append([answerOption]) |> List.rev;
  {...t, answerOptions: newAnswerOptions};
};

let removeAnswerOption = (id, t) => {
  let newAnswerOptions =
    t.answerOptions
    |> List.filter(a => a |> CurriculumEditor__AnswerOption.id !== id);
  {...t, answerOptions: newAnswerOptions};
};

let replace = (id, answerOptionB, t) => {
  let newAnswerOptions =
    t.answerOptions
    |> List.map(a =>
         a |> CurriculumEditor__AnswerOption.id == id ? answerOptionB : a
       );
  {...t, answerOptions: newAnswerOptions};
};

let markAsCorrect = (id, t) => {
  let newAnswerOptions =
    t.answerOptions
    |> List.map(a =>
         a |> CurriculumEditor__AnswerOption.id == id ?
           CurriculumEditor__AnswerOption.markAsCorrect(a) :
           CurriculumEditor__AnswerOption.markAsIncorrect(a)
       );
  {...t, answerOptions: newAnswerOptions};
};