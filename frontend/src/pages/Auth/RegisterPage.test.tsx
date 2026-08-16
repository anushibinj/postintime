import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { RegisterPage } from './RegisterPage';
import { AuthProvider } from '../../app/providers/AuthProvider';
import { register } from '../../api/auth';

vi.mock('../../api/auth', () => ({
  register: vi.fn(),
}));

describe('RegisterPage', () => {
  beforeEach(() => {
    vi.mocked(register).mockReset();
  });

  it('submits typed display name, email, and password to the register API', async () => {
    vi.mocked(register).mockResolvedValue({
      token: 'token',
      userId: 'user-1',
      email: 'anushibin007@gmail.com',
      displayName: 'Shibin',
    });

    render(
      <MemoryRouter>
        <AuthProvider>
          <RegisterPage />
        </AuthProvider>
      </MemoryRouter>,
    );

    fireEvent.change(screen.getByPlaceholderText('Your name'), { target: { value: 'Shibin' } });
    fireEvent.change(screen.getByPlaceholderText('you@example.com'), { target: { value: 'anushibin007@gmail.com' } });
    fireEvent.change(screen.getByPlaceholderText('At least 8 characters'), { target: { value: 'Opentext1!' } });
    fireEvent.click(screen.getByRole('button', { name: 'Register' }));

    await waitFor(() => {
      expect(register).toHaveBeenCalledWith('anushibin007@gmail.com', 'Opentext1!', 'Shibin');
    });
    expect(register).toHaveBeenCalledTimes(1);
  });
});
