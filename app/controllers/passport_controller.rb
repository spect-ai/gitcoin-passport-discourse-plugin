# frozen_string_literal: true

class DiscourseGitcoinPassport::PassportController < ::ApplicationController
  requires_plugin DiscourseGitcoinPassport::PLUGIN_NAME

  before_action :ensure_gitcoin_passport_enabled

  def user_level_gating_score
    begin
      params.require(:user_id)
      params.require(:score)
      params.require(:action_id)
      if !current_user
        render json: { status: 403, error: "You must be logged in to access this resource" } if !current_user
        return
      end
      if !current_user.staff?
        render json: { status: 403, error: "You must be an admin to access this resource" }
        return
      end
      user_passport_scores = UserPassportScore.where(user_id: params[:user_id], user_action_type: params[:action_id])
      if user_passport_scores.exists?
        user_passport_score = user_passport_scores.first
      else
        user_passport_score = UserPassportScore.new
        user_passport_score.user_id = params[:user_id]
        user_passport_score.user_action_type = params[:action_id]
      end
      user_passport_score.required_score = params[:score]
      if user_passport_score.save
        render json: {
          user_passport_score: user_passport_score
        }
      else
        Rails.logger.warn("Error saving user passport score: #{user_passport_score.errors.full_messages.join(", ")}")
        raise DiscourseGitcoinPassport::Error.new(user_passport_score.errors.full_messages.join(", "))
      end
    rescue DiscourseGitcoinPassport::Error => e
      Rails.logger.error("Error saving user passport score: #{e.message}")
      render_json_error e.message
    end
  end

  def category_level_gating_score
    begin
      params.require(:category_id)
      params.require(:score)
      params.require(:action_id)

      if !current_user
        render json: { status: 403, error: "You must be logged in to access this resource" } if !current_user
        return
      end
      category = Category.find(params[:category_id])
      guardian = Guardian.new(current_user)
      if !current_user.staff? && !guardian.is_category_group_moderator?(category)
        render json: { status: 403, error: "You must be an admin to access this resource" }
        return
      end


      category_passport_scores = CategoryPassportScore.where(category_id: params[:category_id], user_action_type: params[:action_id])
      if category_passport_scores.exists?
        category_passport_score = category_passport_scores.first
      else
        category_passport_score = CategoryPassportScore.new
        category_passport_score.category_id = params[:category_id]
        category_passport_score.user_action_type = params[:action_id]
      end
      category_passport_score.required_score = params[:score]
      if category_passport_score.save
        render json: {
          category_passport_score: category_passport_score
        }
      else
        raise DiscourseGitcoinPassport::Error.new(category_passport_score.errors.full_messages.join(", "))
      end
    rescue DiscourseGitcoinPassport::Error => e
      Rails.logger.error("Error saving category passport score: #{e.message}")
      render_json_error e.message
    end
  end


  def refresh_score
    begin
      score = DiscourseGitcoinPassport::Passport.refresh_passport_score(current_user)
      render json: {
        score: score
      }
    rescue DiscourseGitcoinPassport::Error => e
      Rails.logger.error("Error refreshing passport score: #{e.message}")
      render_json_error e.message
    end
  end

  def ensure_gitcoin_passport_enabled
    if !SiteSetting.gitcoin_passport_enabled
      raise Discourse::NotFound.new("Gitcoin Passport is not enabled")
    end
  end
end
