module Mutations
  class UnarchiveCourse < GraphQL::Schema::Mutation
    argument :id, ID, required: true

    description "Un-archives a course."

    field :success, Boolean, null: false

    def resolve(params)
      mutator = UnarchiveCourseMutator.new(context, params)

      success = if mutator.valid?
        mutator.unarchive_course
        true
      else
        mutator.notify_errors
        false
      end

      { success: success }
    end
  end
end
