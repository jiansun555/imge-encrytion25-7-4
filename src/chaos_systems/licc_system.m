function [x_out, y_out, z_out] = licc_system(x0, y0, z0, a, b, c, num_iterations, discard_transients)
% licc_system: Generates chaotic sequences using the LICC hyperchaotic system.
%
% Args:
%   x0, y0, z0: Initial values for x, y, z.
%   a, b, c: Parameters of the LICC system.
%   num_iterations: Total number of iterations to generate after discarding transients.
%   discard_transients: Number of initial iterations to discard. (Optional, default 1000)
%
% Returns:
%   x_out, y_out, z_out: Generated chaotic sequences (row vectors).
%
% Notes:
%   The LICC system equations are based on the paper by Buyu Liu et al. (the user's paper),
%   which cites Wei & Li (2022) for the LICC system.
%   User's paper equations (Eq. 1):
%   x(i+1) = cos[c(1/(a*y(i)*(1-y(i))) + 1/(a*z(i)*(1-z(i))) + b)] * sin[π/x(i)]
%   y(i+1) = cos[c(1/(a*x(i)*(1-x(i))) + 1/(a*z(i)*(1-z(i))) + b)] * sin[π/y(i)]
%   z(i+1) = cos[c(1/(a*x(i)*(1-x(i))) + 1/(a*y(i)*(1-y(i))) + b/z(i))] * sin[π]
%
%   The z(i+1) equation with sin[π] is problematic as sin[π] = 0, leading to z always being 0.
%   This would then cause division by zero in the terms 1/(a*z(i)*(1-z(i))).
%
%   The plan is to use a symmetric form for z(i+1) consistent with x and y,
%   and also to clarify whether the update is parallel or sequential.
%   The paper by Wei & Li (2022), "A novel image encryption scheme based on LICC hyperchaotic system and DNA coding",
%   uses these equations (parallel update):
%   x_{n+1} = cos(c(1/ay_n(1-y_n) + 1/az_n(1-z_n) + b))sin(\pi/x_n)
%   y_{n+1} = cos(c(1/ax_n(1-x_n) + 1/az_n(1-z_n) + b))sin(\pi/y_n)
%   z_{n+1} = cos(c(1/ax_n(1-x_n) + 1/ay_n(1-y_n) + b))sin(\pi/z_n)
%
%   This implementation will use the parallel update structure from Wei & Li (2022)
%   as it's the likely intended source and is mathematically sound.

    if nargin < 8
        discard_transients = 1000; % Default number of transients to discard
    end
    if nargin < 7
        error('licc_system requires at least 7 arguments: x0, y0, z0, a, b, c, num_iterations');
    end

    total_points_to_generate = num_iterations + discard_transients;

    % Preallocate arrays
    x_all = zeros(1, total_points_to_generate);
    y_all = zeros(1, total_points_to_generate);
    z_all = zeros(1, total_points_to_generate);

    % Set initial conditions
    x_i = x0;
    y_i = y0;
    z_i = z0;

    for k = 1:total_points_to_generate
        % Store current values for RHS calculation (parallel update)
        x_curr = x_i;
        y_curr = y_i;
        z_curr = z_i;

        % --- Parameter checks for potential division by zero or invalid operations ---
        % For terms like 1/(a*val*(1-val))
        if y_curr == 0 || y_curr == 1
            error('LICC Error: y_curr is %f, causing division by zero in 1/(a*y(1-y)). Iteration k=%d.', y_curr, k);
        end
        if z_curr == 0 || z_curr == 1
            error('LICC Error: z_curr is %f, causing division by zero in 1/(a*z(1-z)). Iteration k=%d.', z_curr, k);
        end
        if x_curr == 0 || x_curr == 1
             error('LICC Error: x_curr is %f, causing division by zero in 1/(a*x(1-x)). Iteration k=%d.', x_curr, k);
        end
        % For terms like sin(pi/val)
        if x_curr == 0
            error('LICC Error: x_curr is 0, causing division by zero in sin(pi/x_curr). Iteration k=%d.', k);
        end
        if y_curr == 0
            error('LICC Error: y_curr is 0, causing division by zero in sin(pi/y_curr). Iteration k=%d.', k);
        end
        if z_curr == 0
            error('LICC Error: z_curr is 0, causing division by zero in sin(pi/z_curr). Iteration k=%d.', k);
        end
        % --- End Parameter checks ---

        % Calculate next states based on current states (parallel update)
        term_yz_for_x = (1 / (a * y_curr * (1 - y_curr))) + (1 / (a * z_curr * (1 - z_curr)));
        x_next = cos(c * (term_yz_for_x + b)) * sin(pi / x_curr);

        term_xz_for_y = (1 / (a * x_curr * (1 - x_curr))) + (1 / (a * z_curr * (1 - z_curr)));
        y_next = cos(c * (term_xz_for_y + b)) * sin(pi / y_curr);

        term_xy_for_z = (1 / (a * x_curr * (1 - x_curr))) + (1 / (a * y_curr * (1 - y_curr)));
        z_next = cos(c * (term_xy_for_z + b)) * sin(pi / z_curr);

        % Store calculated next states
        x_all(k) = x_next;
        y_all(k) = y_next;
        z_all(k) = z_next;

        % Update states for the next iteration
        x_i = x_next;
        y_i = y_next;
        z_i = z_next;
    end

    % Discard transients
    if discard_transients >= total_points_to_generate && num_iterations > 0
         warning('LICC: discard_transients (%d) is >= total points generated (%d). Returning empty sequences.', discard_transients, total_points_to_generate);
         x_out = []; y_out = []; z_out = [];
    elseif num_iterations == 0 % If only transients are requested (e.g. for bifurcation)
        x_out = x_all(1:discard_transients);
        y_out = y_all(1:discard_transients);
        z_out = z_all(1:discard_transients);
    else
        start_index = discard_transients + 1;
        if start_index > total_points_to_generate
             x_out = []; y_out = []; z_out = []; % Not enough points generated
        else
            x_out = x_all(start_index : end);
            y_out = y_all(start_index : end);
            z_out = z_all(start_index : end);
        end
    end

    % Ensure output are row vectors
    x_out = reshape(x_out, 1, []);
    y_out = reshape(y_out, 1, []);
    z_out = reshape(z_out, 1, []);
end

% % Example Usage (can be commented out or moved to a test script `test_licc.m`)
% if 0 % Set to 1 to run example when this file is executed
%     clc; clearvars; close all; % Clear variables for a clean test run
%
%     % Parameters from the user's paper (Buyu Liu et al.)
%     x0_paper = 0.3;
%     y0_paper = 1.5; % This is outside [-1,1] range mentioned in Fig 3 caption
%     z0_paper = 0.9;
%     a_paper = 3.9;
%     b_paper = pi;
%     c_paper = pi;
%
%     num_iterations_paper = 50000;
%     discard_transients_paper = 1000; % Typical value for discarding transients
%
%     fprintf('Running LICC system with paper initial values (y0=1.5)...\n');
%     fprintf('Using parallel update and symmetric z equation from Wei & Li (2022).\n');
%
%     % The LICC system as defined can be sensitive to initial conditions being exactly 0 or 1,
%     % or leading to intermediate values that are 0 or 1.
%     % The values x,y,z are shown in Fig.3 to be within [-1,1].
%     % An initial y0=1.5 is outside this. Let's test if it converges into [-1,1].
%
%     % Test with paper's y0 = 1.5
%     y0_test = y0_paper;
%     % A quick check: y(1-y) = 1.5 * (1-1.5) = 1.5 * (-0.5) = -0.75. This is non-zero.
%     % sin(pi/x0) = sin(pi/0.3) - well defined.
%
%     try
%         [x_s, y_s, z_s] = licc_system(x0_paper, y0_test, z0_paper, ...
%                                      a_paper, b_paper, c_paper, ...
%                                      num_iterations_paper, discard_transients_paper);
%
%         if isempty(x_s)
%             fprintf('LICC system returned empty sequences. Check parameters or transient handling.\n');
%             return;
%         end
%
%         disp(['Generated ', num2str(length(x_s)), ' points after transients.']);
%
%         figure('Name', ['LICC Attractor (y0=', num2str(y0_test), ')']);
%         subplot(2,2,1);
%         plot3(x_s, y_s, z_s, '.', 'MarkerSize', 0.5);
%         title({'LICC System 3D Attractor', '(Parallel, Symmetric z)'});
%         xlabel('x'); ylabel('y'); zlabel('z');
%         axis tight; grid on;
%         view(30, 20); % Adjust view angle
%
%         subplot(2,2,2);
%         plot(x_s, y_s, '.', 'MarkerSize', 0.5);
%         title('x-y projection');
%         xlabel('x'); ylabel('y');
%         axis tight; grid on;
%
%         subplot(2,2,3);
%         plot(x_s, z_s, '.', 'MarkerSize', 0.5);
%         title('x-z projection');
%         xlabel('x'); ylabel('z');
%         axis tight; grid on;
%
%         subplot(2,2,4);
%         plot(y_s, z_s, '.', 'MarkerSize', 0.5);
%         title('y-z projection');
%         xlabel('y'); ylabel('z');
%         axis tight; grid on;
%
%         sgtitle(['LICC System: x0=',num2str(x0_paper),', y0=',num2str(y0_test),', z0=',num2str(z0_paper), ...
%                  ', a=',num2str(a_paper),', b=\pi, c=\pi'], 'FontSize', 10);
%
%     catch ME
%         fprintf('Error during LICC system execution: %s\n', ME.message);
%         fprintf('Error in file: %s, line: %d\n', ME.stack(1).file, ME.stack(1).line);
%     end
% end```matlab
function [x_out, y_out, z_out] = licc_system(x0, y0, z0, a, b, c, num_iterations, discard_transients)
% licc_system: Generates chaotic sequences using the LICC hyperchaotic system.
%
% Args:
%   x0, y0, z0: Initial values for x, y, z.
%   a, b, c: Parameters of the LICC system.
%   num_iterations: Total number of iterations to generate after discarding transients.
%   discard_transients: Number of initial iterations to discard. (Optional, default 1000)
%
% Returns:
%   x_out, y_out, z_out: Generated chaotic sequences (row vectors).
%
% Notes:
%   The LICC system equations are based on the paper by Buyu Liu et al. (the user's paper),
%   which cites Wei & Li (2022) for the LICC system.
%   User's paper equations (Eq. 1):
%   x(i+1) = cos[c(1/(a*y(i)*(1-y(i))) + 1/(a*z(i)*(1-z(i))) + b)] * sin[π/x(i)]
%   y(i+1) = cos[c(1/(a*x(i)*(1-x(i))) + 1/(a*z(i)*(1-z(i))) + b)] * sin[π/y(i)]
%   z(i+1) = cos[c(1/(a*x(i)*(1-x(i))) + 1/(a*y(i)*(1-y(i))) + b/z(i))] * sin[π]
%
%   The z(i+1) equation with sin[π] is problematic as sin[π] = 0, leading to z always being 0.
%   This would then cause division by zero in the terms 1/(a*z(i)*(1-z(i))).
%
%   The plan is to use a symmetric form for z(i+1) consistent with x and y,
%   and also to clarify whether the update is parallel or sequential.
%   The paper by Wei & Li (2022), "A novel image encryption scheme based on LICC hyperchaotic system and DNA coding",
%   uses these equations (parallel update):
%   x_{n+1} = cos(c(1/ay_n(1-y_n) + 1/az_n(1-z_n) + b))sin(\pi/x_n)
%   y_{n+1} = cos(c(1/ax_n(1-x_n) + 1/az_n(1-z_n) + b))sin(\pi/y_n)
%   z_{n+1} = cos(c(1/ax_n(1-x_n) + 1/ay_n(1-y_n) + b))sin(\pi/z_n)
%
%   This implementation will use the parallel update structure from Wei & Li (2022)
%   as it's the likely intended source and is mathematically sound.

    if nargin < 8
        discard_transients = 1000; % Default number of transients to discard
    end
    if nargin < 7
        error('licc_system requires at least 7 arguments: x0, y0, z0, a, b, c, num_iterations');
    end

    total_points_to_generate = num_iterations + discard_transients;

    % Preallocate arrays
    x_all = zeros(1, total_points_to_generate);
    y_all = zeros(1, total_points_to_generate);
    z_all = zeros(1, total_points_to_generate);

    % Set initial conditions
    x_i = x0;
    y_i = y0;
    z_i = z0;

    for k = 1:total_points_to_generate
        % Store current values for RHS calculation (parallel update)
        x_curr = x_i;
        y_curr = y_i;
        z_curr = z_i;

        % --- Parameter checks for potential division by zero or invalid operations ---
        % For terms like 1/(a*val*(1-val))
        if y_curr == 0 || y_curr == 1
            error('LICC Error: y_curr is %f, causing division by zero in 1/(a*y(1-y)). Iteration k=%d.', y_curr, k);
        end
        if z_curr == 0 || z_curr == 1
            error('LICC Error: z_curr is %f, causing division by zero in 1/(a*z(1-z)). Iteration k=%d.', z_curr, k);
        end
        if x_curr == 0 || x_curr == 1
             error('LICC Error: x_curr is %f, causing division by zero in 1/(a*x(1-x)). Iteration k=%d.', x_curr, k);
        end
        % For terms like sin(pi/val)
        if x_curr == 0
            error('LICC Error: x_curr is 0, causing division by zero in sin(pi/x_curr). Iteration k=%d.', k);
        end
        if y_curr == 0
            error('LICC Error: y_curr is 0, causing division by zero in sin(pi/y_curr). Iteration k=%d.', k);
        end
        if z_curr == 0
            error('LICC Error: z_curr is 0, causing division by zero in sin(pi/z_curr). Iteration k=%d.', k);
        end
        % --- End Parameter checks ---

        % Calculate next states based on current states (parallel update)
        term_yz_for_x = (1 / (a * y_curr * (1 - y_curr))) + (1 / (a * z_curr * (1 - z_curr)));
        x_next = cos(c * (term_yz_for_x + b)) * sin(pi / x_curr);

        term_xz_for_y = (1 / (a * x_curr * (1 - x_curr))) + (1 / (a * z_curr * (1 - z_curr)));
        y_next = cos(c * (term_xz_for_y + b)) * sin(pi / y_curr);

        term_xy_for_z = (1 / (a * x_curr * (1 - x_curr))) + (1 / (a * y_curr * (1 - y_curr)));
        z_next = cos(c * (term_xy_for_z + b)) * sin(pi / z_curr);

        % Store calculated next states
        x_all(k) = x_next;
        y_all(k) = y_next;
        z_all(k) = z_next;

        % Update states for the next iteration
        x_i = x_next;
        y_i = y_next;
        z_i = z_next;
    end

    % Discard transients
    if discard_transients >= total_points_to_generate && num_iterations > 0
         warning('LICC: discard_transients (%d) is >= total points generated (%d). Returning empty sequences.', discard_transients, total_points_to_generate);
         x_out = []; y_out = []; z_out = [];
    elseif num_iterations == 0 % If only transients are requested (e.g. for bifurcation)
        x_out = x_all(1:discard_transients);
        y_out = y_all(1:discard_transients);
        z_out = z_all(1:discard_transients);
    else
        start_index = discard_transients + 1;
        if start_index > total_points_to_generate
             x_out = []; y_out = []; z_out = []; % Not enough points generated
        else
            x_out = x_all(start_index : end);
            y_out = y_all(start_index : end);
            z_out = z_all(start_index : end);
        end
    end

    % Ensure output are row vectors
    x_out = reshape(x_out, 1, []);
    y_out = reshape(y_out, 1, []);
    z_out = reshape(z_out, 1, []);
end

% % Example Usage (can be commented out or moved to a test script `test_licc.m`)
% if 0 % Set to 1 to run example when this file is executed
%     clc; clearvars; close all; % Clear variables for a clean test run
%
%     % Parameters from the user's paper (Buyu Liu et al.)
%     x0_paper = 0.3;
%     y0_paper = 1.5; % This is outside [-1,1] range mentioned in Fig 3 caption
%     z0_paper = 0.9;
%     a_paper = 3.9;
%     b_paper = pi;
%     c_paper = pi;
%
%     num_iterations_paper = 50000;
%     discard_transients_paper = 1000; % Typical value for discarding transients
%
%     fprintf('Running LICC system with paper initial values (y0=1.5)...\n');
%     fprintf('Using parallel update and symmetric z equation from Wei & Li (2022).\n');
%
%     % The LICC system as defined can be sensitive to initial conditions being exactly 0 or 1,
%     % or leading to intermediate values that are 0 or 1.
%     % The values x,y,z are shown in Fig.3 to be within [-1,1].
%     % An initial y0=1.5 is outside this. Let's test if it converges into [-1,1].
%
%     % Test with paper's y0 = 1.5
%     y0_test = y0_paper;
%     % A quick check: y(1-y) = 1.5 * (1-1.5) = 1.5 * (-0.5) = -0.75. This is non-zero.
%     % sin(pi/x0) = sin(pi/0.3) - well defined.
%
%     try
%         [x_s, y_s, z_s] = licc_system(x0_paper, y0_test, z0_paper, ...
%                                      a_paper, b_paper, c_paper, ...
%                                      num_iterations_paper, discard_transients_paper);
%
%         if isempty(x_s)
%             fprintf('LICC system returned empty sequences. Check parameters or transient handling.\n');
%             return;
%         end
%
%         disp(['Generated ', num2str(length(x_s)), ' points after transients.']);
%
%         figure('Name', ['LICC Attractor (y0=', num2str(y0_test), ')']);
%         subplot(2,2,1);
%         plot3(x_s, y_s, z_s, '.', 'MarkerSize', 0.5);
%         title({'LICC System 3D Attractor', '(Parallel, Symmetric z)'});
%         xlabel('x'); ylabel('y'); zlabel('z');
%         axis tight; grid on;
%         view(30, 20); % Adjust view angle
%
%         subplot(2,2,2);
%         plot(x_s, y_s, '.', 'MarkerSize', 0.5);
%         title('x-y projection');
%         xlabel('x'); ylabel('y');
%         axis tight; grid on;
%
%         subplot(2,2,3);
%         plot(x_s, z_s, '.', 'MarkerSize', 0.5);
%         title('x-z projection');
%         xlabel('x'); ylabel('z');
%         axis tight; grid on;
%
%         subplot(2,2,4);
%         plot(y_s, z_s, '.', 'MarkerSize', 0.5);
%         title('y-z projection');
%         xlabel('y'); ylabel('z');
%         axis tight; grid on;
%
%         sgtitle(['LICC System: x0=',num2str(x0_paper),', y0=',num2str(y0_test),', z0=',num2str(z0_paper), ...
%                  ', a=',num2str(a_paper),', b=\pi, c=\pi'], 'FontSize', 10);
%
%     catch ME
%         fprintf('Error during LICC system execution: %s\n', ME.message);
%         fprintf('Error in file: %s, line: %d\n', ME.stack(1).file, ME.stack(1).line);
%     end
% end
```
