module Bosh::Director
  module DeploymentPlan
    class SerialMultiJobUpdater
      def initialize(job_updater_factory)
        @job_updater_factory = job_updater_factory
      end

      def update(base_job, deployment_plan, jobs)
        run_updates(base_job, deployment_plan, jobs, :update)
      end

      def post_deploy(base_job, deployment_plan, jobs)
        run_updates(base_job, deployment_plan, jobs, :post_deploy)
      end

      private

      def run_updates(base_job, deployment_plan, jobs, action)
        base_job.logger.info("Running #{action} serially for jobs: #{jobs.map(&:name).join(', ')}")

        jobs.each do |j|
          base_job.task_checkpoint
          base_job.logger.info("Running #{action} on job: #{j.name}")
          job_updater = @job_updater_factory.new_job_updater(deployment_plan, j)
          job_updater.send(action)
        end
      end
    end

    class ParallelMultiJobUpdater
      def initialize(job_updater_factory)
        @job_updater_factory = job_updater_factory
      end

      def update(base_job, deployment_plan, jobs)
        run_updates(base_job, deployment_plan, jobs, :update)
      end

      def post_deploy(base_job, deployment_plan, jobs)
        run_updates(base_job, deployment_plan, jobs, :post_deploy)
      end

      private

      def run_updates(base_job, deployment_plan, jobs, action)
        base_job.logger.info("Running #{action} in parallel for jobs: #{jobs.map(&:name).join(', ')}")
        base_job.task_checkpoint

        ThreadPool.new(max_threads: jobs.size).wrap do |pool|
          jobs.each do |j|
            pool.process do
              base_job.logger.info("Running #{action} for job: #{j.name}")
              job_updater = @job_updater_factory.new_job_updater(deployment_plan, j)
              job_updater.send(action)
            end
          end
        end
      end
    end

    class BatchMultiJobUpdater
      def initialize(job_updater_factory)
        @job_updater_factory = job_updater_factory
      end

      def update(base_job, deployment_plan, jobs)
        run_updates(base_job, deployment_plan, jobs, :update)
      end

      def post_deploy(base_job, deployment_plan, jobs)
        run_updates(base_job, deployment_plan, jobs, :post_deploy)
      end

      private

      def run_updates(base_job, deployment_plan, jobs, action)
        serial_updater = SerialMultiJobUpdater.new(@job_updater_factory)
        parallel_updater = ParallelMultiJobUpdater.new(@job_updater_factory)
        partition_jobs_by_serial(jobs).each do |jp|
          updater = jp.first.update.serial? ? serial_updater : parallel_updater
          updater.send(action, base_job, deployment_plan, jp)
        end
      end

      def partition_jobs_by_serial(jobs)
        job_partitions = []
        last_partition = []

        jobs.each do |j|
          lastj = last_partition.last
          if !lastj || lastj.update.serial? == j.update.serial?
            last_partition << j
          else
            job_partitions << last_partition
            last_partition = [j]
          end
        end

        job_partitions << last_partition if last_partition.any?
        job_partitions
      end
    end
  end
end
