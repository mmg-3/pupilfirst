module Schools
  class TargetGroupsController < SchoolsController
    # POST /school/levels/:level_id/target_groups(.:format)
    def create
      level = Level.find(params[:level_id])
      target_group = authorize(TargetGroup.new(level: level), policy_class: Schools::TargetGroupPolicy)
      form = ::Schools::TargetGroups::CreateForm.new(target_group)
      if form.validate(params[:target_group])
        form.save
        redirect_back(fallback_location: school_course_curriculum_path(target_group.course))
      else
        raise form.errors.full_messages.join(', ')
      end
    end

    # PATCH /school/target_groups/:id
    def update
      target_group = authorize(TargetGroup.find(params[:id]), policy_class: Schools::TargetGroupPolicy)
      form = ::Schools::TargetGroups::UpdateForm.new(target_group)
      if form.validate(params[:target_group])
        form.save
        redirect_back(fallback_location: school_course_curriculum_path(target_group.course))
      else
        raise form.errors.full_messages.join(', ')
      end
    end
  end
end