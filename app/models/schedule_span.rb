class ScheduleSpan < ActiveRecord::Base

	belongs_to :schedule
	
	def content
		return YAML.load(self[:content])
	end
	
	def previous
		schedule.schedule_spans.where("id < ?", self.id).last
	end
	
	def next
		schedule.schedule_spans.where("id > ?", self.id).first
	end

end
