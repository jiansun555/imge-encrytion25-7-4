function analyze_chaos()
% analyze_chaos: Performs and visualizes various analyses of chaotic systems.
%   - LICC system: Phase diagrams, bifurcation diagrams, initial value sensitivity.
%   - Logistic map: Bifurcation diagram, initial value sensitivity.

    fprintf('Starting Chaos Analysis...\n');

    % --- LICC System Analysis ---
    fprintf('\n--- Analyzing LICC System ---\n');
    % Parameters from the user's paper (Buyu Liu et al.)
    x0_licc = 0.3;
    y0_licc = 1.5; % This is outside [-1,1] range mentioned in Fig 3 caption, but used in paper
    z0_licc = 0.9;
    a_licc = 3.9;
    b_licc = pi;
    c_licc = pi;

    num_iter_attractor = 50000; % For attractor plots
    discard_trans_attractor = 1000;

    % 1. LICC Phase Diagrams (Attractors)
    fprintf('Generating LICC phase diagrams (attractors)...\n');
    try
        [x_s, y_s, z_s] = licc_system(x0_licc, y0_licc, z0_licc, ...
                                     a_licc, b_licc, c_licc, ...
                                     num_iter_attractor, discard_trans_attractor);

        if ~isempty(x_s)
            h_fig_licc_attractor = figure('Name', 'LICC Attractor Plots');
            subplot(2,2,1);
            plot3(x_s, y_s, z_s, '.', 'MarkerSize', 0.5, 'Color', [0 0.4470 0.7410]); % Blue
            title({'LICC 3D Attractor', '(Parallel, Symmetric z)'});
            xlabel('x'); ylabel('y'); zlabel('z');
            axis tight; grid on; view(30, 20);

            subplot(2,2,2);
            plot(x_s, y_s, '.', 'MarkerSize', 0.5, 'Color', [0.8500 0.3250 0.0980]); % Orange
            title('x-y projection'); xlabel('x'); ylabel('y');
            axis tight; grid on;

            subplot(2,2,3);
            plot(x_s, z_s, '.', 'MarkerSize', 0.5, 'Color', [0.9290 0.6940 0.1250]); % Yellow
            title('x-z projection'); xlabel('x'); ylabel('z');
            axis tight; grid on;

            subplot(2,2,4);
            plot(y_s, z_s, '.', 'MarkerSize', 0.5, 'Color', [0.4940 0.1840 0.5560]); % Purple
            title('y-z projection'); xlabel('y'); ylabel('z');
            axis tight; grid on;

            sgtitle_text = sprintf('LICC Attractors: x0=%.1f, y0=%.1f, z0=%.1f, a=%.1f, b=%.2f, c=%.2f', ...
                                   x0_licc, y0_licc, z0_licc, a_licc, b_licc, c_licc);
            sgtitle(h_fig_licc_attractor, sgtitle_text, 'FontSize', 10);
            % Save figure
            % saveas(h_fig_licc_attractor, 'results/licc_attractors.png');
            fprintf('LICC phase diagrams generated.\n');
        else
            fprintf('LICC system returned empty sequences for attractors. Skipping plots.\n');
        end
    catch ME
        fprintf('Error generating LICC phase diagrams: %s\n', ME.message);
    end

    % 2. LICC Bifurcation Diagrams (as in Fig. 4 of the user's paper)
    fprintf('Generating LICC bifurcation diagrams...\n');
    num_iter_bif = 300; % Number of points to plot for each parameter value
    discard_trans_bif = 500; % Transients for each run
    param_steps = 200; % Number of steps for the varying parameter

    % Bifurcation with respect to 'a'
    a_range = linspace(0, 5, param_steps); % As per Fig 4 description
    b_fixed_for_a_bif = pi;
    c_fixed_for_a_bif = pi;
    x_bif_a = [];
    param_vals_a = [];

    try
        for a_val = a_range
            [~, ~, z_bif_temp] = licc_system(x0_licc, y0_licc, z0_licc, ...
                                           a_val, b_fixed_for_a_bif, c_fixed_for_a_bif, ...
                                           num_iter_bif, discard_trans_bif);
            if ~isempty(z_bif_temp)
                x_bif_a = [x_bif_a, z_bif_temp]; % Plotting z values for bifurcation
                param_vals_a = [param_vals_a, repmat(a_val, 1, length(z_bif_temp))];
            end
        end
        if ~isempty(x_bif_a)
            h_fig_licc_bif_a = figure('Name', 'LICC Bifurcation vs a');
            plot(param_vals_a, x_bif_a, '.', 'MarkerSize', 1);
            title('LICC Bifurcation Diagram: z vs a (b=\pi, c=\pi)');
            xlabel('Parameter a'); ylabel('z');
            grid on; axis tight;
            % saveas(h_fig_licc_bif_a, 'results/licc_bifurcation_vs_a.png');
        end
        fprintf('LICC bifurcation diagram vs a generated.\n');
    catch ME
         fprintf('Error generating LICC bifurcation for a: %s (a_val=%f)\n', ME.message, a_val);
    end

    % Bifurcation with respect to 'b'
    b_range = linspace(0, 5, param_steps);
    a_fixed_for_b_bif = 3.9;
    c_fixed_for_b_bif = pi;
    x_bif_b = [];
    param_vals_b = [];
    try
        for b_val = b_range
            [~, ~, z_bif_temp] = licc_system(x0_licc, y0_licc, z0_licc, ...
                                           a_fixed_for_b_bif, b_val, c_fixed_for_b_bif, ...
                                           num_iter_bif, discard_trans_bif);
            if ~isempty(z_bif_temp)
                x_bif_b = [x_bif_b, z_bif_temp];
                param_vals_b = [param_vals_b, repmat(b_val, 1, length(z_bif_temp))];
            end
        end
        if ~isempty(x_bif_b)
            h_fig_licc_bif_b = figure('Name', 'LICC Bifurcation vs b');
            plot(param_vals_b, x_bif_b, '.', 'MarkerSize', 1);
            title('LICC Bifurcation Diagram: z vs b (a=3.9, c=\pi)');
            xlabel('Parameter b'); ylabel('z');
            grid on; axis tight;
            % saveas(h_fig_licc_bif_b, 'results/licc_bifurcation_vs_b.png');
        end
        fprintf('LICC bifurcation diagram vs b generated.\n');
    catch ME
        fprintf('Error generating LICC bifurcation for b: %s (b_val=%f)\n', ME.message, b_val);
    end

    % Bifurcation with respect to 'c'
    c_range = linspace(0, 5, param_steps);
    a_fixed_for_c_bif = 3.9;
    b_fixed_for_c_bif = pi;
    x_bif_c = [];
    param_vals_c = [];
    try
        for c_val = c_range
            [~, ~, z_bif_temp] = licc_system(x0_licc, y0_licc, z0_licc, ...
                                           a_fixed_for_c_bif, b_fixed_for_c_bif, c_val, ...
                                           num_iter_bif, discard_trans_bif);
            if ~isempty(z_bif_temp)
                x_bif_c = [x_bif_c, z_bif_temp];
                param_vals_c = [param_vals_c, repmat(c_val, 1, length(z_bif_temp))];
            end
        end
        if ~isempty(x_bif_c)
            h_fig_licc_bif_c = figure('Name', 'LICC Bifurcation vs c');
            plot(param_vals_c, x_bif_c, '.', 'MarkerSize', 1);
            title('LICC Bifurcation Diagram: z vs c (a=3.9, b=\pi)');
            xlabel('Parameter c'); ylabel('z');
            grid on; axis tight;
            % saveas(h_fig_licc_bif_c, 'results/licc_bifurcation_vs_c.png');
        end
        fprintf('LICC bifurcation diagram vs c generated.\n');
    catch ME
        fprintf('Error generating LICC bifurcation for c: %s (c_val=%f)\n', ME.message, c_val);
    end

    % 3. LICC Initial Value Sensitivity
    fprintf('Generating LICC initial value sensitivity test...\n');
    delta = 1e-10;
    num_iter_sensitivity = 500;
    discard_trans_sensitivity = 0; % Show from the beginning for sensitivity
    try
        [x1_licc, y1_licc, z1_licc] = licc_system(x0_licc, y0_licc, z0_licc, a_licc, b_licc, c_licc, num_iter_sensitivity, discard_trans_sensitivity);
        [x2_licc, y2_licc, z2_licc] = licc_system(x0_licc + delta, y0_licc, z0_licc, a_licc, b_licc, c_licc, num_iter_sensitivity, discard_trans_sensitivity);

        if ~isempty(x1_licc) && ~isempty(x2_licc)
            diff_x_licc = abs(x1_licc - x2_licc);
            h_fig_licc_sens = figure('Name', 'LICC Initial Value Sensitivity');
            semilogy(1:num_iter_sensitivity, diff_x_licc, 'LineWidth', 1);
            title(['LICC Sensitivity: |x1 - x2|, delta x0 = ', num2str(delta)]);
            xlabel('Iteration'); ylabel('Absolute Difference (log scale)');
            grid on; axis tight;
            % saveas(h_fig_licc_sens, 'results/licc_sensitivity.png');
            fprintf('LICC initial value sensitivity test generated.\n');
        else
            fprintf('LICC system returned empty sequences for sensitivity test. Skipping.\n');
        end
    catch ME
        fprintf('Error in LICC sensitivity test: %s\n', ME.message);
    end

    % --- Logistic Map Analysis ---
    fprintf('\n--- Analyzing Logistic Map ---\n');
    x0_logistic = 0.5;
    lambda_logistic = 4.0; % For chaos

    % 1. Logistic Map Bifurcation Diagram
    fprintf('Generating Logistic map bifurcation diagram...\n');
    lambda_range_logistic = linspace(2.5, 4.0, 400);
    num_iter_bif_log = 200;
    discard_trans_bif_log = 300;
    x_bif_logistic = [];
    param_vals_logistic = [];
    try
        for lam_val = lambda_range_logistic
            x_temp_log = logistic_map(x0_logistic, lam_val, num_iter_bif_log, discard_trans_bif_log);
            if ~isempty(x_temp_log)
                x_bif_logistic = [x_bif_logistic, x_temp_log];
                param_vals_logistic = [param_vals_logistic, repmat(lam_val, 1, length(x_temp_log))];
            end
        end
        if ~isempty(x_bif_logistic)
            h_fig_log_bif = figure('Name', 'Logistic Map Bifurcation');
            plot(param_vals_logistic, x_bif_logistic, '.', 'MarkerSize', 1);
            title('Logistic Map Bifurcation Diagram (x0=0.5)');
            xlabel('Parameter \lambda'); ylabel('x');
            grid on; axis tight;
            % saveas(h_fig_log_bif, 'results/logistic_bifurcation.png');
            fprintf('Logistic map bifurcation diagram generated.\n');
        end
    catch ME
        fprintf('Error generating Logistic bifurcation: %s (lambda_val=%f)\n', ME.message, lam_val);
    end

    % 2. Logistic Map Initial Value Sensitivity
    fprintf('Generating Logistic map initial value sensitivity test...\n');
    try
        x1_log = logistic_map(x0_logistic, lambda_logistic, num_iter_sensitivity, discard_trans_sensitivity);
        x2_log = logistic_map(x0_logistic + delta, lambda_logistic, num_iter_sensitivity, discard_trans_sensitivity);

        if ~isempty(x1_log) && ~isempty(x2_log)
            diff_x_log = abs(x1_log - x2_log);
            h_fig_log_sens = figure('Name', 'Logistic Map Initial Value Sensitivity');
            semilogy(1:num_iter_sensitivity, diff_x_log, 'LineWidth', 1);
            title(['Logistic Map Sensitivity: |x1 - x2|, delta x0 = ', num2str(delta), ', \lambda=', num2str(lambda_logistic)]);
            xlabel('Iteration'); ylabel('Absolute Difference (log scale)');
            grid on; axis tight;
            % saveas(h_fig_log_sens, 'results/logistic_sensitivity.png');
            fprintf('Logistic map initial value sensitivity test generated.\n');
        else
             fprintf('Logistic map returned empty sequences for sensitivity test. Skipping.\n');
        end
    catch ME
        fprintf('Error in Logistic map sensitivity test: %s\n', ME.message);
    end

    fprintf('\nChaos Analysis Complete.\n');
    fprintf('NOTE: To save figures, uncomment the "saveas" lines in the code.\n');
    fprintf('Consider creating a "results" directory if it does not exist for saving figures.\n');

end

% % Example of how to run this analysis (from command window or a main script)
% if 0 % Set to 1 to run when this file is executed
%     clc; clearvars; close all;
%     % Ensure chaos_systems directory is on path or run from parent directory
%     % addpath('src/chaos_systems'); % if analyze_chaos is in src/chaos_systems
%
%     % Create results directory if it doesn't exist
%     if ~exist('results', 'dir')
%        mkdir('results');
%        fprintf('Created "results" directory.\n');
%     end
%     analyze_chaos();
% end
