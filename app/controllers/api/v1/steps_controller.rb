# frozen_string_literal: true

module Api
  module V1
    class StepsController < BaseController
      include Api::V1::ExtraParams

      before_action :load_team, :load_project, :load_experiment, :load_task, :load_protocol
      before_action only: :show do
        load_step(:id)
      end
      before_action :load_step_for_managing, only: %i(update destroy)

      def index
        steps = @protocol.steps.page(params.dig(:page, :number)).per(params.dig(:page, :size))

        render jsonapi: steps, each_serializer: StepSerializer,
                               include: include_params,
                               rte_rendering: render_rte?,
                               team: @team
      end

      def show
        render jsonapi: @step, serializer: StepSerializer,
                               include: include_params,
                               rte_rendering: render_rte?,
                               team: @team
      end

      def create
        raise PermissionError.new(Protocol, :create) unless can_manage_protocol_in_module?(@protocol)

        step = @protocol.steps.create!(step_params.merge!(completed: false,
                                                          user: current_user,
                                                          position: @protocol.number_of_steps))

        render jsonapi: step, serializer: StepSerializer, status: :created
      end

      def update
        @step.assign_attributes(step_params)

        if @step.changed? && @step.save!
          if @step.saved_change_to_attribute?(:completed)
            completed_steps = @protocol.steps.where(completed: true).count
            all_steps = @protocol.steps.count
            type_of = @step.saved_change_to_attribute(:completed).last ? :complete_step : :uncomplete_step
            log_activity(type_of, my_module: @task.id,
                                  num_completed: completed_steps.to_s,
                                  num_all: all_steps.to_s)
          end
          render jsonapi: @step, serializer: StepSerializer, status: :ok
        else
          render body: nil, status: :no_content
        end
      end

      def destroy
        @step.destroy!
        render body: nil
      end

      private

      def step_params
        raise TypeError unless params.require(:data).require(:type) == 'steps'

        params.require(:data).require(:attributes).permit(:name, :description, :completed)
      end

      def permitted_includes
        %w(tables assets checklists checklists.checklist_items comments user)
      end

      def load_step_for_managing
        @step = @protocol.steps.find(params.require(:id))
        raise PermissionError.new(Protocol, :manage) unless can_manage_protocol_in_module?(@step.protocol)
      end

      def log_activity(type_of, message_items = {})
        default_items = { step: @step.id, step_position: { id: @step.id, value_for: 'position_plus_one' } }
        message_items = default_items.merge(message_items)

        Activities::CreateActivityService.call(activity_type: type_of,
                                               owner: current_user,
                                               subject: @protocol,
                                               team: @team,
                                               project: @project,
                                               message_items: message_items)
      end
    end
  end
end
