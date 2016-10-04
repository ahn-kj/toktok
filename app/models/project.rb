class Project < ApplicationRecord
  acts_as_paranoid

  belongs_to :proposal, required: false
  belongs_to :user
  belongs_to :committee
  has_many :likes, as: :likable
  has_many :comments, as: :commentable
  has_many :attachments, dependent: :destroy, as: :attachable
  has_many :participations, dependent: :destroy
  has_many :matches, dependent: :destroy
  has_many :matched_congressmen, through: :matches, source: :congressman

  validates :title, presence: true

  accepts_nested_attributes_for :attachments, reject_if: proc { |params| params[:source].blank? and params[:source_cache].blank? and params[:id].blank? }, allow_destroy: true

  before_save :squish_texts
  # mount
  mount_uploader :image, ImageUploader

  STATUS = {
    'gathering' => {
      title: "'시민참여'단계에서는 시민의 제안을 받아 지지를 받습니다."
    },
    'matching' => {
      title: "'의원매칭'단계에서는 1000명 이상의 지지를 받은 제안을 의원과 연결합니다."
    },
    'running' => {
      title: "'입법활동'단계에서는 실제로 의원과 함께 입법을 위한 활동을 합니다."
    }
  }

  def participant? someone
    participations.exists? user: someone
  end

  def status
    if participations_count < participations_goal_count
      :gathering
    elsif matches.having_status(:accept).any?
      :running
    else
      :matching
    end
  end

  def status_of_congressman(congressman)
    match = matches.find_by congressman: congressman
    if match.present?
      return match.status
    else
      :ready
    end
  end

  def unmathed_congressmen
    Congressman.where.not(id: matched_congressmen)
  end

  def participations_percentage
    return 0 if participations_goal_count == 0
    (participations_count / participations_goal_count.to_f * 100).to_i
  end

  def sould_reject_comment_of? someone
    return true if someone.blank?
    return !(participant?(someone))
  end

  private

  def squish_texts
    %i(body summary proposer_description).each do |text_field|
      self.send(text_field).try(:squish!)
    end
  end
end
