"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Check, Plus, Trash2, X } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  createQuiz,
  deleteQuestion,
  deleteQuiz,
  saveQuestion,
} from "@/app/actions/quizzes";
import type { QuizQuestionWithOptions, QuizWithQuestions } from "@/lib/types";

/**
 * Attaches a quiz to a course or a lesson, and edits its questions.
 *
 * Rendered in two places with the same component: once per lesson as a
 * checkpoint, once at the foot of the course as the final assessment.
 * The only difference is whether `lessonId` is passed.
 */
export function QuizEditor({
  courseId,
  lessonId,
  quiz,
  label,
}: {
  courseId: string;
  lessonId?: string;
  quiz?: QuizWithQuestions;
  /** What this quiz is called in the UI, e.g. "Final assessment". */
  label: string;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  async function create() {
    setBusy(true);
    try {
      const result = await createQuiz({
        courseId,
        lessonId,
        title: lessonId ? "Lesson check" : "Final assessment",
        passPercent: 70,
      });
      if (!result.ok) return toast.error(result.error);
      toast.success("Quiz added — now add some questions.");
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  async function remove() {
    if (
      !window.confirm(
        "Delete this quiz? Its questions and every learner's attempts go " +
          "with it, and anyone who passed it will no longer count as having " +
          "completed the course.",
      )
    ) {
      return;
    }
    setBusy(true);
    try {
      const result = await deleteQuiz(quiz!.id, courseId);
      if (!result.ok) return toast.error(result.error);
      toast.success("Quiz deleted.");
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  if (!quiz) {
    return (
      <Button variant="outline" size="sm" disabled={busy} onClick={create}>
        <Plus className="mr-1.5 h-3.5 w-3.5" />
        Add {label.toLowerCase()}
      </Button>
    );
  }

  const questionCount = quiz.quiz_questions?.length ?? 0;

  return (
    <div className="rounded-lg border bg-muted/30 p-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium">{quiz.title}</span>
          <Badge variant="outline">
            {questionCount} {questionCount === 1 ? "question" : "questions"}
          </Badge>
          <Badge variant="outline">Pass at {quiz.pass_percent}%</Badge>
          {questionCount === 0 && (
            <Badge
              variant="destructive"
              title="A quiz with no questions can't be submitted, so nobody can complete this course."
            >
              Needs questions
            </Badge>
          )}
        </div>
        <div className="flex items-center gap-1">
          <QuestionDialog courseId={courseId} quizId={quiz.id} />
          <Button
            variant="ghost"
            size="icon"
            className="h-8 w-8 text-destructive hover:text-destructive"
            disabled={busy}
            onClick={remove}
            title="Delete quiz"
          >
            <Trash2 className="h-3.5 w-3.5" />
          </Button>
        </div>
      </div>

      {questionCount > 0 && (
        <ol className="mt-3 space-y-2">
          {quiz.quiz_questions.map((q, i) => (
            <QuestionRow
              key={q.id}
              index={i + 1}
              question={q}
              courseId={courseId}
              quizId={quiz.id}
            />
          ))}
        </ol>
      )}
    </div>
  );
}

function QuestionRow({
  index,
  question,
  courseId,
  quizId,
}: {
  index: number;
  question: QuizQuestionWithOptions;
  courseId: string;
  quizId: string;
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);

  const answer = (question.quiz_options ?? []).find((o) => o.is_correct);

  async function remove() {
    if (!window.confirm("Delete this question?")) return;
    setBusy(true);
    try {
      const result = await deleteQuestion(question.id, courseId);
      if (!result.ok) return toast.error(result.error);
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  return (
    <li className="flex items-start justify-between gap-2 rounded-md bg-background p-2.5">
      <div className="min-w-0">
        <p className="text-sm">
          <span className="text-muted-foreground">{index}.</span>{" "}
          {question.prompt}
        </p>
        <p className="mt-0.5 truncate text-xs text-muted-foreground">
          {(question.quiz_options ?? []).length} options
          {answer ? ` · answer: ${answer.label}` : " · no correct answer set"}
        </p>
      </div>
      <div className="flex shrink-0 items-center gap-1">
        <QuestionDialog
          courseId={courseId}
          quizId={quizId}
          question={question}
        />
        <Button
          variant="ghost"
          size="icon"
          className="h-7 w-7 text-destructive hover:text-destructive"
          disabled={busy}
          onClick={remove}
        >
          <Trash2 className="h-3 w-3" />
        </Button>
      </div>
    </li>
  );
}

interface DraftOption {
  label: string;
  isCorrect: boolean;
}

function QuestionDialog({
  courseId,
  quizId,
  question,
}: {
  courseId: string;
  quizId: string;
  question?: QuizQuestionWithOptions;
}) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState(false);

  const [prompt, setPrompt] = useState(question?.prompt ?? "");
  const [explanation, setExplanation] = useState(question?.explanation ?? "");
  const [options, setOptions] = useState<DraftOption[]>(
    question
      ? (question.quiz_options ?? []).map((o) => ({
          label: o.label,
          isCorrect: o.is_correct,
        }))
      : [
          { label: "", isCorrect: true },
          { label: "", isCorrect: false },
        ],
  );

  function setCorrect(index: number) {
    // Radio behaviour, not checkbox: exactly one answer is correct, which
    // is what saveQuestion enforces server-side too.
    setOptions((prev) => prev.map((o, i) => ({ ...o, isCorrect: i === index })));
  }

  function setLabel(index: number, label: string) {
    setOptions((prev) => prev.map((o, i) => (i === index ? { ...o, label } : o)));
  }

  function addOption() {
    setOptions((prev) => [...prev, { label: "", isCorrect: false }]);
  }

  function removeOption(index: number) {
    setOptions((prev) => {
      const next = prev.filter((_, i) => i !== index);
      // Removing the correct answer would leave a question nobody can get
      // right, so the first remaining option inherits it.
      if (!next.some((o) => o.isCorrect) && next.length > 0) {
        next[0] = { ...next[0], isCorrect: true };
      }
      return next;
    });
  }

  async function submit() {
    setBusy(true);
    try {
      const result = await saveQuestion({
        quizId,
        courseId,
        questionId: question?.id,
        prompt,
        explanation,
        options,
      });
      if (!result.ok) return toast.error(result.error);

      toast.success(question ? "Question updated." : "Question added.");
      setOpen(false);
      if (!question) {
        setPrompt("");
        setExplanation("");
        setOptions([
          { label: "", isCorrect: true },
          { label: "", isCorrect: false },
        ]);
      }
      router.refresh();
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        {question ? (
          <Button variant="ghost" size="sm" className="h-7">
            Edit
          </Button>
        ) : (
          <Button variant="outline" size="sm">
            <Plus className="mr-1.5 h-3.5 w-3.5" />
            Question
          </Button>
        )}
      </DialogTrigger>
      <DialogContent className="max-h-[90vh] overflow-y-auto sm:max-w-lg">
        <DialogHeader>
          <DialogTitle>{question ? "Edit question" : "New question"}</DialogTitle>
          <DialogDescription>
            Single answer. Learners see the options in this order, and the
            explanation after they answer.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div className="space-y-1.5">
            <Label htmlFor="prompt">Question</Label>
            <Textarea
              id="prompt"
              rows={2}
              value={prompt}
              onChange={(e) => setPrompt(e.target.value)}
              placeholder="What is the purpose of the breath in this practice?"
            />
          </div>

          <div className="space-y-2">
            <Label>Options — click the circle to mark the correct one</Label>
            {options.map((option, i) => (
              <div key={i} className="flex items-center gap-2">
                <button
                  type="button"
                  onClick={() => setCorrect(i)}
                  title="Mark as the correct answer"
                  className={
                    "flex h-6 w-6 shrink-0 items-center justify-center rounded-full border transition-colors " +
                    (option.isCorrect
                      ? "border-green-600 bg-green-600 text-white"
                      : "border-input hover:border-green-600")
                  }
                >
                  {option.isCorrect && <Check className="h-3.5 w-3.5" />}
                </button>
                <Input
                  value={option.label}
                  onChange={(e) => setLabel(i, e.target.value)}
                  placeholder={`Option ${i + 1}`}
                />
                <Button
                  type="button"
                  variant="ghost"
                  size="icon"
                  className="h-8 w-8 shrink-0"
                  disabled={options.length <= 2}
                  onClick={() => removeOption(i)}
                  title={
                    options.length <= 2
                      ? "A question needs at least two options"
                      : "Remove option"
                  }
                >
                  <X className="h-3.5 w-3.5" />
                </Button>
              </div>
            ))}
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={addOption}
            >
              <Plus className="mr-1.5 h-3.5 w-3.5" />
              Add option
            </Button>
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="explanation">Explanation (optional)</Label>
            <Textarea
              id="explanation"
              rows={2}
              value={explanation}
              onChange={(e) => setExplanation(e.target.value)}
              placeholder="Shown after answering, whether they got it right or wrong."
            />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => setOpen(false)}>
            Cancel
          </Button>
          <Button disabled={busy} onClick={submit}>
            {busy ? "Saving…" : question ? "Save changes" : "Add question"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
