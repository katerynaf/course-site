class Grade < ActiveRecord::Base

	belongs_to :submit
	has_one :user, through: :submit
	has_one :pset, through: :submit
	belongs_to :grader, class_name: "User"

	before_save :set_calculated_grade, :unpublicize_if_undone
	
	serialize :subgrades, OpenStruct
	
	enum status: [:open, :finished, :published, :discussed]
	
	def public?
		published? or discussed?
	end

	def subgrades=(val)
		# we would like this to be stored as an OpenStruct
		return super if val.is_a? OpenStruct
		
		# take this opportunity to convert any stringified ints from the params to ints
		val.each do |k,v|
			val[k] = v.to_i if v.to_i.to_s == v
		end if val
		
		super OpenStruct.new val.to_h if val
	end
	
	def grade
		g = read_attribute(:grade)
		return nil if !g
		g = (g/10.0).round(1)
		return g
	end
	
	def calculated_grade
		g = read_attribute(:calculated_grade)
		return nil if !g
		g = (g/10.0).round(1)
		return g
	end
	
	def any_final_grade
    # this function prefers hard-coded grades but can also provide the calculated grade
		self.grade or self.calculated_grade
	end

	def grade=(new_grade)
		if new_grade.blank? # erases the grade
			return super(nil)
		elsif new_grade.class == String
			new_grade.sub!(/,/,'.')
			case self.pset.grade_type
			when 'float'
				super(10.0 * new_grade.to_f)
			else # integer, pass
				super(10.0 * new_grade.to_i)
			end
		else
			case self.pset.grade_type
			when 'float'
				super(10.0 * new_grade.to_f)
			else # integer, pass
				super(10.0 * new_grade.to_i)
			end
		end
	end
	
	def set_calculated_grade
		if calculated_grade = calculate_grade(self)
			case self.pset.grade_type
			when 'float'
				# calculated_grade = calculated_grade
			else # integer, pass
				calculated_grade = calculated_grade.round
			end
			# self.update_attribute(:calculated_grade, calculated_grade*10)
			self.calculated_grade = calculated_grade * 10
		else
			# self.update_attribute(:calculated_grade, nil)
			self.calculated_grade = nil
		end
	end

	private
	
	def calculate_grade(grade)
		puts grade.inspect
		f = Settings['grading']['grades'] if Settings['grading']
		return nil if f.nil?
		pset_name = grade.pset.name
		return nil if f[pset_name].nil? or f[pset_name]['calculation'].nil?
		begin
			cg = grade.subgrades.instance_eval(f[pset_name]['calculation'])
		rescue
			cg = nil
		end
		return cg
	end
	
	def unpublicize_if_undone
		self.status = Grade.statuses[:open] unless self.any_final_grade.present?
		true
	end

end
