import React from 'react';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import NavigationBar from './NavigationBar';

describe('NavigationBar', () => {
  test('renders the navigation bar with correct links in Portuguese', () => {
    render(
      <MemoryRouter>
        <NavigationBar />
      </MemoryRouter>
    );

    // Check for the presence of the navigation bar itself
    expect(screen.getByRole('navigation')).toBeInTheDocument();

    // Check for "Início" link (Home)
    const homeLink = screen.getByRole('link', { name: /início/i });
    expect(homeLink).toBeInTheDocument();
    expect(homeLink).toHaveAttribute('href', '/');

    // Check for "Adicionar Novo Paciente" link (Add Patient)
    const addPatientLink = screen.getByRole('link', { name: /adicionar novo paciente/i });
    expect(addPatientLink).toBeInTheDocument();
    expect(addPatientLink).toHaveAttribute('href', '/add-patient');
  });
});
