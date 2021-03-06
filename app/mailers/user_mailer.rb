class UserMailer < ApplicationMailer

  def new_lesson_email(lesson, current)
    @student = lesson.student
    @tutor = lesson.tutor
    @subject = lesson.subject
    @date = lesson.date
    @current = current
    @lesson = lesson
    @url = 'http://www.tutorial.academy'

    subject = 'Tutorial Academy - A student has requested a lesson from you'

    # Tutor has set up the lesson - so email the student (else - opposite)
    if @current.is_a? Tutor
      subject = 'Tutorial Academy - A tutor has set up a lesson with you'
      mail(to: @student.email, subject: subject)
    else
      mail(to: @tutor.email, subject: subject)
    end
  end

  def lesson_change_email(lesson, current)
    @student = lesson.student
    @tutor = lesson.tutor
    @subject = lesson.subject
    @date = lesson.date
    @current = current
    @lesson = lesson
    @url = 'http://www.tutorial.academy'

    subject = 'Tutorial Academy - The details of one of your scheduled lessons have changed'
    to = @tutor
    if @current.is_a? Tutor
      to = @student
    end

    mail(to: to.email, subject: subject)
  end
end
